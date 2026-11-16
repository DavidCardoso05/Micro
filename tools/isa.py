_ABI_NAMES = [
    "zero", "at", "v0", "v1", "a0", "a1", "a2", "a3",
    "t0", "t1", "t2", "t3", "t4", "t5", "t6", "t7",
    "s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7",
    "t8", "t9", "k0", "k1", "gp", "sp", "fp", "ra"
]

REGISTERS = {}

#"$t0" -> 8, "$8" -> 8 ....
for _num, _name in enumerate(_ABI_NAMES):
    REGISTERS["$" + _name] = _num
    REGISTERS["$" + str(_num)] = _num

REG_NAMES = ["$" + n for n in _ABI_NAMES]

REG_AT = 1
REG_RA = 31

FMT_R = "R" #opcode | rs | rt | rd | shamt | funct
FMT_I = "I" #opcode | rs | rt | immediate
FMT_J = "J" #opcode | address
FMT_CP0 = "CP0"

FIELDS = {
    "opcode": (26, 6),
    "rs": (21, 5),
    "rt": (16, 5),
    "rd": (11, 5),
    "shamt": (6, 5),
    "funct": (0, 6),
    "imm": (0, 16),
    "address": (0, 26),
    "sel": (0, 3),
    "sc": (5, 1)
}

FORMAT_FIELDS = {
    FMT_R: ("opcode", "rs", "rt", "rd", "shamt", "funct"),
    FMT_I: ("opcode", "rs", "rt", "imm"),
    FMT_J: ("opcode", "address"),
    FMT_CP0: ("opcode", "rs", "rt", "rd", "sc", "sel"),
}

OP_RTYPE = 0x00
OP_REGIMM = 0x01 #bgez (rt = 00001)
OP_J = 0x02
OP_JAL = 0x03
OP_BEQ = 0x04
OP_BNE = 0x05
OP_BGTZ = 0x07
OP_ADDI = 0x08
OP_XORI = 0x0E
OP_LUI = 0x0F
OP_COP0 = 0x10 #mfc0, ei, di
OP_LB = 0x20
OP_LW = 0x23
OP_SW = 0x2B

F_SLL = 0x00
F_SRL = 0x02
F_JR = 0x08
F_ADD = 0x20
F_SUB = 0x22
F_AND = 0x24
F_OR = 0x25
F_XOR = 0x26
F_NOR = 0x27
F_SLT = 0x2A

# fixed fields
RT_BGEZ  = 0b00001   # REGIMM sub-opcode
RT_BGTZ  = 0b00000
RS_MFC0  = 0b00000   # COP0 rs = MF
RS_MFMC0 = 0b01011   # COP0 rs = MFMC0 (di / ei)
RD_EPC   = 14        # mfc0 reads CP0 register 14 (EPC)
RD_SR    = 0b01100   # di / ei: CP0 register 12 (Status)

# ---------------------------------------------------------------------------
# Operand syntax tokens
# ---------------------------------------------------------------------------
# Each instruction lists its operands in source order. Token meanings:
#   "rd", "rs", "rt"  register written into that field
#   "shamt"           0..31 into the shamt field
#   "simm"            signed 16-bit immediate      (-32768 .. 32767)
#   "uimm"            unsigned 16-bit immediate    (0 .. 0xFFFF)
#   "mem"             imm(rs): signed 16-bit offset + base register
#   "branch"          label -> (target - (PC + 4)) >> 2, signed 16
#   "jump"            label -> target[27:2]
#   "cp0"             CP0 register number; only $14 (EPC) is accepted
#   "rt0?"            optional register that must be $zero (di / ei)

SIMM16_MIN, SIMM16_MAX = -32768, 32767
UIMM16_MIN, UIMM16_MAX = 0, 0xFFFF
SHAMT_MIN, SHAMT_MAX = 0, 31

class Instr(object):
    def __init__(self, mnemonic, fmt, operands, fixed):
        self.mnemonic = mnemonic
        self.fmt = fmt
        self.operands = tuple(operands)
        self.fixed = dict(fixed)

    def __repr__(self):
        return f"Instr(%s, %s, %s)" % (self.mnemonic, self.fmt, self.operands)

def _r(m, funct, operands=("rd", "rs", "rt")): #typed as -> mnemonic rd, rs, rt
    return Instr(m, FMT_R, operands, {"opcode": OP_RTYPE, "funct": funct})

def _i(m, opcode, operands, **fixed):
    f = {"opcode": opcode}
    f.update(fixed)
    return Instr(m, FMT_I, operands, f)

_TABLE = [
    #------Class wide ISA ---------------------------------------------------
    _r("add",  F_ADD),
    _r("sub",  F_SUB),
    _r("and",  F_AND),
    _r("or",   F_OR),
    _r("xor",  F_XOR),
    _r("slt",  F_SLT),
    _r("sll", F_SLL, ("rd", "rt", "shamt")),
    _r("srl", F_SRL, ("rd", "rt", "shamt")),
    _r("jr",  F_JR, ("rs",)),

    _i("addi", OP_ADDI, ("rt", "rs", "simm")),
    _i("lw", OP_LW, ("rt", "mem")),
    _i("sw", OP_SW, ("rt", "mem")),
    _i("beq", OP_BEQ, ("rs", "rt", "branch")),
    _i("bne", OP_BNE, ("rs", "rt", "branch")),
    _i("lui", OP_LUI, ("rt", "uimm")),

    Instr("j", FMT_J, ("jump",), {"opcode": OP_J}),
    Instr("jal", FMT_J, ("jump",), {"opcode": OP_JAL}),

    #-------------------- Group selected instructions --------------------------------
    _r("nor", F_NOR),

    _i("xori", OP_XORI, ("rt", "rs", "uimm")),
    _i("lb", OP_LB, ("rt", "mem")),
    _i("bgez", OP_REGIMM, ("rs", "branch"), rt=RT_BGEZ),
    _i("bgtz", OP_BGTZ, ("rs", "branch"), rt=RT_BGTZ),

    Instr("mfc0", FMT_CP0, ("rt", "cp0"),
        {"opcode": OP_COP0, "rs": RS_MFC0, "rd": RD_EPC, "sel": 0}),
    Instr("di", FMT_CP0, ("rt0?",),
          {"opcode": OP_COP0, "rs": RS_MFMC0, "rd": RD_SR, "sc": 0}),
    Instr("ei", FMT_CP0, ("rt0?",),
            {"opcode": OP_COP0, "rs": RS_MFMC0, "rd": RD_SR, "sc": 1})
]

