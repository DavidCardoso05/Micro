"""
isa.py - ISA definition for our MIPS32 (subset).

This file is the single source of truth for the binary format of the
instructions. It must match rtl/control_unit.v: if you add an instruction to
the hardware, add it here (INSTRUCTIONS table) and the assembler will know it
with no other changes.

Contents:
  1. Registers (name -> number)
  2. Instruction fields (bit positions) and pack/unpack
  3. Operand kinds
  4. Instruction table
  5. encode(): numeric operands -> 32-bit word
  6. decode(): 32-bit word -> text (disassembler, for listings)

This module knows nothing about assembly text, labels or files: that is the
job of assembler.py.
"""

from dataclasses import dataclass, field


class IsaError(Exception):
    """Encoding error (invalid register, immediate out of range, ...)."""


# =============================================================================
# 1. Registers
# =============================================================================
# MIPS convention: the index in the list is the register number.
REG_NAMES = [
    "zero", "at", "v0", "v1", "a0", "a1", "a2", "a3",
    "t0", "t1", "t2", "t3", "t4", "t5", "t6", "t7",
    "s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7",
    "t8", "t9", "k0", "k1", "gp", "sp", "fp", "ra",
]

# Accepts both styles: $t0 and $8.
REGISTERS = {}
for _num, _name in enumerate(REG_NAMES):
    REGISTERS["$" + _name] = _num
    REGISTERS["$" + str(_num)] = _num
REGISTERS["$s8"] = 30  # alternative name for $fp


def reg_number(token):
    """'$t0' -> 8. Raises IsaError if the name does not exist."""
    num = REGISTERS.get(token.strip().lower())
    if num is None:
        raise IsaError(f"registo desconhecido: '{token.strip()}'")
    return num


# =============================================================================
# 2. Fields
# =============================================================================
# name -> (least significant bit, width). The R, I and J formats are just
# different combinations of these fields:
#
#   R: | opcode 6 | rs 5 | rt 5 | rd 5 | shamt 5 | funct 6 |
#   I: | opcode 6 | rs 5 | rt 5 |        imm 16           |
#   J: | opcode 6 |            target 26                  |
FIELDS = {
    "opcode": (26, 6),
    "rs": (21, 5),
    "rt": (16, 5),
    "rd": (11, 5),
    "shamt": (6, 5),
    "funct": (0, 6),
    "imm": (0, 16),
    "target": (0, 26),
}


def pack(fields):
    """{'opcode': 8, 'rt': 8, 'imm': 5} -> 0x20080005.

    Each value is truncated to the field width (so negative immediates come
    out in two's complement). Range checking is done earlier, in encode().
    """
    word = 0
    for name, value in fields.items():
        lo, width = FIELDS[name]
        word |= (value & ((1 << width) - 1)) << lo
    return word


def unpack(word, name):
    """Extracts a field from a word: unpack(0x20080005, 'rt') -> 8."""
    lo, width = FIELDS[name]
    return (word >> lo) & ((1 << width) - 1)


def sign_extend(value, bits):
    """Interprets 'value' (with 'bits' bits) as a signed number."""
    if value & (1 << (bits - 1)):
        return value - (1 << bits)
    return value


# =============================================================================
# 3. Operand kinds
# =============================================================================
# Each instruction declares the list of its operands, in the order they are
# written in assembly. The kind says how the value is checked and which field
# it goes into:
#
#   rd, rs, rt  register, goes into the field with the same name
#   shamt       0..31, shamt field (sll, srl)
#   simm        signed immediate, -32768..32767 (addi: SignExt)
#   uimm        unsigned immediate, 0..65535 (xori, lui: ZeroExt)
#   mem         offset(rs): signed offset in imm, base register in rs
#   branch      target address; encodes (target - (PC+4)) / 4 in imm
#   jump        target address; encodes target[27:2] in target
#   cp0         CP0 register; only 14 (EPC) exists, goes into rd
OPERAND_KINDS = ("rd", "rs", "rt", "shamt", "simm", "uimm", "mem", "branch", "jump", "cp0")


# =============================================================================
# 4. Instruction table
# =============================================================================
@dataclass(frozen=True)
class InstrDef:
    name: str
    fmt: str  # "R", "I" or "J" (informative only: pack uses the fields)
    operands: tuple  # operand kinds, in assembly order
    fixed: dict = field(default_factory=dict)  # constant fields (opcode, funct, ...)


def _instr(name, fmt, operands, **fixed):
    ops = tuple(operands.split(",")) if operands else ()
    for kind in ops:
        assert kind in OPERAND_KINDS, kind
    return InstrDef(name, fmt, ops, fixed)


# Opcodes / funct are the same as in rtl/control_unit.v.
_TABLE = [
    # ---------- R: rd <- rs op rt ----------
    _instr("add", "R", "rd,rs,rt", opcode=0x00, funct=0x20),
    _instr("sub", "R", "rd,rs,rt", opcode=0x00, funct=0x22),
    _instr("and", "R", "rd,rs,rt", opcode=0x00, funct=0x24),
    _instr("or", "R", "rd,rs,rt", opcode=0x00, funct=0x25),
    _instr("xor", "R", "rd,rs,rt", opcode=0x00, funct=0x26),
    _instr("nor", "R", "rd,rs,rt", opcode=0x00, funct=0x27),
    _instr("slt", "R", "rd,rs,rt", opcode=0x00, funct=0x2A),
    # ---------- R: shifts (rd <- rt << shamt), rs = 0 ----------
    _instr("sll", "R", "rd,rt,shamt", opcode=0x00, funct=0x00),
    _instr("srl", "R", "rd,rt,shamt", opcode=0x00, funct=0x02),
    # ---------- R: jr ----------
    _instr("jr", "R", "rs", opcode=0x00, funct=0x08),
    # ---------- I: ALU with immediate ----------
    _instr("addi", "I", "rt,rs,simm", opcode=0x08),
    _instr("xori", "I", "rt,rs,uimm", opcode=0x0E),
    _instr("lui", "I", "rt,uimm", opcode=0x0F),
    # ---------- I: memory (address = rs + SignExt(imm)) ----------
    _instr("lb", "I", "rt,mem", opcode=0x20),
    _instr("lw", "I", "rt,mem", opcode=0x23),
    _instr("sw", "I", "rt,mem", opcode=0x2B),
    # ---------- I: branches ----------
    _instr("beq", "I", "rs,rt,branch", opcode=0x04),
    _instr("bne", "I", "rs,rt,branch", opcode=0x05),
    _instr("bgez", "I", "rs,branch", opcode=0x01, rt=0b00001),  # REGIMM
    _instr("bgtz", "I", "rs,branch", opcode=0x07, rt=0b00000),
    # ---------- J ----------
    _instr("j", "J", "jump", opcode=0x02),
    _instr("jal", "J", "jump", opcode=0x03),
    # ---------- CP0 (opcode 0x10) ----------
    # mfc0 rt, $14   -> rs = 00000 (MF), rd = 14, sel = 000
    _instr("mfc0", "R", "rt,cp0", opcode=0x10, rs=0b00000, funct=0x00),
    # di / ei       -> rs = 01011 (MFMC0), rd = 12 (Status), bit 5 = sc
    _instr("di", "R", "", opcode=0x10, rs=0b01011, rt=0, rd=12, funct=0x00),
    _instr("ei", "R", "", opcode=0x10, rs=0b01011, rt=0, rd=12, funct=0x20),
]

INSTRUCTIONS = {d.name: d for d in _TABLE}


# =============================================================================
# 5. encode
# =============================================================================
def _check_range(value, lo, hi, what):
    if not lo <= value <= hi:
        raise IsaError(f"{what} fora da gama [{lo}, {hi}]: {value}")
    return value


def encode(name, args, pc=0):
    """Encodes a real instruction.

    name: mnemonic ('addi')
    args: already numeric values, one per operand in the table:
          registers -> number; immediates -> int; mem -> (offset, base);
          branch/jump -> absolute target address
    pc:   address of this instruction (needed for branch and jump)
    """
    d = INSTRUCTIONS.get(name)
    if d is None:
        raise IsaError(f"instrucao desconhecida: '{name}'")
    if len(args) != len(d.operands):
        raise IsaError(f"'{name}' espera {len(d.operands)} operando(s), recebeu {len(args)}")

    f = dict(d.fixed)
    for kind, val in zip(d.operands, args):
        if kind in ("rd", "rs", "rt"):
            f[kind] = _check_range(val, 0, 31, "registo")
        elif kind == "shamt":
            f["shamt"] = _check_range(val, 0, 31, "shamt")
        elif kind == "simm":
            f["imm"] = _check_range(val, -32768, 32767, "imediato com sinal")
        elif kind == "uimm":
            f["imm"] = _check_range(val, 0, 0xFFFF, "imediato sem sinal")
        elif kind == "mem":
            offset, base = val
            f["imm"] = _check_range(offset, -32768, 32767, "offset")
            f["rs"] = base
        elif kind == "branch":
            # next_pc.v: target = (PC + 4) + (SignExt(imm) << 2)
            delta = val - (pc + 4)
            if delta % 4:
                raise IsaError(f"destino do branch nao alinhado: 0x{val:X}")
            f["imm"] = _check_range(delta // 4, -32768, 32767, "distancia do branch (palavras)")
        elif kind == "jump":
            # next_pc.v: target = {(PC + 4)[31:28], target, 00}
            if val % 4:
                raise IsaError(f"destino do jump nao alinhado: 0x{val:X}")
            if (val ^ (pc + 4)) & 0xF0000000:
                raise IsaError(f"destino do jump fora da regiao de 256 MiB: 0x{val:X}")
            f["target"] = (val >> 2) & 0x3FFFFFF
        elif kind == "cp0":
            if val != 14:
                raise IsaError(f"so o registo 14 (EPC) do CP0 esta implementado, nao {val}")
            f["rd"] = 14
    return pack(f)


# =============================================================================
# 6. decode (disassembler)
# =============================================================================
def _reg(num):
    return "$" + REG_NAMES[num]


def decode(word, pc=None):
    """0x20080005 -> 'addi $t0, $zero, 5'.

    Looks for the instruction whose fixed fields match the word. With 'pc',
    branches and jumps show the target address instead of the offset.
    """
    if word == 0:
        return "nop"
    for d in _TABLE:
        if all(unpack(word, k) == v for k, v in d.fixed.items()):
            break
    else:
        return f".word 0x{word:08X}"

    out = []
    for kind in d.operands:
        if kind in ("rd", "rs", "rt"):
            out.append(_reg(unpack(word, kind)))
        elif kind == "shamt":
            out.append(str(unpack(word, "shamt")))
        elif kind == "simm":
            out.append(str(sign_extend(unpack(word, "imm"), 16)))
        elif kind == "uimm":
            out.append(f"0x{unpack(word, 'imm'):X}")
        elif kind == "mem":
            out.append(f"{sign_extend(unpack(word, 'imm'), 16)}({_reg(unpack(word, 'rs'))})")
        elif kind == "branch":
            off = sign_extend(unpack(word, "imm"), 16)
            out.append(f"0x{pc + 4 + 4 * off:X}" if pc is not None else f"{off:+d}")
        elif kind == "jump":
            target = unpack(word, "target") << 2
            if pc is not None:
                target |= (pc + 4) & 0xF0000000
            out.append(f"0x{target:X}")
        elif kind == "cp0":
            out.append("$" + str(unpack(word, "rd")))
    return d.name + (" " + ", ".join(out) if out else "")
