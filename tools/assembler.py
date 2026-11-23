#!/usr/bin/env python3
"""
assembler.py - Two-pass assembler for our MIPS32.

Usage:
    python3 tools/assembler.py prog.asm                 # writes prog.mem (+ prog_data.mem)
    python3 tools/assembler.py prog.asm -o program.mem -d data.mem -l prog.lst

Outputs ($readmemh format, one 32-bit word per line):
  - IMEM: instructions (.text), for the INIT_FILE of instruction_memory.v
  - DMEM: data (.data), for the INIT_FILE of data_memory.v (only if there is data)
  - optional listing: address, word, disassembly and original line

The two memories are separate (Harvard), each 2 KiB starting at 0.

Supported syntax:
  comments        # ...  (also // ...)
  labels          name:   (may be alone on a line)
  numbers         10, -3, 0x1F, 0b101, 'A'
  expressions     label, label+4, CONST-1, %hi(label), %lo(label)
  directives      .text .data .org .align .space .word .byte .ascii .asciiz
                  .eqv/.equ/.set NAME, value    .globl (ignored)
  pseudo-instr.   nop move not clear li la b beqz bnez blt bgt ble bge
"""

import argparse
import ast
import re
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import isa  # noqa: E402

MEM_SIZE = {"text": 2048, "data": 2048}  # bytes in each memory


class AsmError(Exception):
    def __init__(self, msg, line=None):
        super().__init__(msg)
        self.line = line


class UndefinedSymbol(AsmError):
    pass


# =============================================================================
# 1. Parsing each line
# =============================================================================
def strip_comment(text):
    """Removes '# ...' and '// ...', ignoring anything inside quotes."""
    quote = None
    i = 0
    while i < len(text):
        c = text[i]
        if quote:
            if c == "\\":
                i += 1  # skip the escaped character
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "#" or text.startswith("//", i):
            return text[:i]
        i += 1
    return text


def split_operands(text):
    """'$t0, 4($sp)' -> ['$t0', '4($sp)']. Commas inside quotes do not count."""
    parts, cur, quote = [], "", None
    i = 0
    while i < len(text):
        c = text[i]
        if quote:
            cur += c
            if c == "\\" and i + 1 < len(text):
                i += 1
                cur += text[i]
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
            cur += c
        elif c == ",":
            parts.append(cur.strip())
            cur = ""
        else:
            cur += c
        i += 1
    if cur.strip() or parts:
        parts.append(cur.strip())
    return parts


LABEL_RE = re.compile(r"\s*([A-Za-z_][\w.]*)\s*:")


@dataclass
class Line:
    num: int  # line number in the file (for error messages)
    text: str  # original line
    labels: list
    op: str  # mnemonic or directive, lowercase ('' if none)
    args: list  # operands, still as text


def parse_line(num, raw):
    text = strip_comment(raw)
    labels = []
    while True:
        m = LABEL_RE.match(text)
        if not m:
            break
        labels.append(m.group(1))
        text = text[m.end():]
    text = text.strip()
    if not text:
        return Line(num, raw.rstrip(), labels, "", [])
    parts = text.split(None, 1)  # mnemonic + rest (separated by spaces or tabs)
    rest = parts[1] if len(parts) > 1 else ""
    return Line(num, raw.rstrip(), labels, parts[0].lower(), split_operands(rest))


# =============================================================================
# 2. Expressions
# =============================================================================
TOKEN_RE = re.compile(
    r"\s*(?:"
    r"(?P<char>'(?:\\.|[^'\\])')"
    r"|(?P<num>0[xX][0-9a-fA-F]+|0[bB][01]+|\d+)"
    r"|(?P<sym>[A-Za-z_][\w.]*)"
    r"|(?P<op>[+-])"
    r")"
)


def eval_expr(text, symbols):
    """Evaluates 'label+4', '0x10', '-3', %hi(x), %lo(x). Returns an int."""
    text = text.strip()
    m = re.fullmatch(r"%(hi|lo)\((.*)\)", text)
    if m:
        v = eval_expr(m.group(2), symbols) & 0xFFFFFFFF
        return (v >> 16) if m.group(1) == "hi" else (v & 0xFFFF)

    total, sign, expect_value, pos = 0, 1, True, 0
    while pos < len(text):
        m = TOKEN_RE.match(text, pos)
        if not m or m.end() == pos:
            raise AsmError(f"expressao invalida: '{text}'")
        pos = m.end()
        if m.group("op"):
            if m.group("op") == "-":
                sign = -sign
            expect_value = True
            continue
        if not expect_value:
            raise AsmError(f"expressao invalida: '{text}'")
        if m.group("char"):
            value = ord(ast.literal_eval(m.group("char")))
        elif m.group("num"):
            value = int(m.group("num"), 0)
        else:
            name = m.group("sym")
            if name not in symbols:
                raise UndefinedSymbol(f"simbolo nao definido: '{name}'")
            value = symbols[name]
        total += sign * value
        sign, expect_value = 1, False
    if expect_value:
        raise AsmError(f"expressao incompleta: '{text}'")
    return total


def parse_string(token):
    """'"ola\\n"' -> b'ola\\n'."""
    token = token.strip()
    if len(token) < 2 or token[0] != '"' or token[-1] != '"':
        raise AsmError(f"string esperada entre aspas: {token}")
    return ast.literal_eval(token).encode("latin-1")


# =============================================================================
# 3. Pseudo-instructions
# =============================================================================
# Each pseudo-instruction is replaced by one or more real instructions. This
# happens in the 1st pass, because the number of generated instructions
# changes the addresses of the labels that follow. Pseudo-branches use $at.
def expand_pseudo(op, args, symbols):
    """Returns the list [(mnemonic, [operands])], or None if 'op' is not a pseudo."""

    def need(n):
        if len(args) != n:
            raise AsmError(f"'{op}' espera {n} operando(s)")

    if op == "nop":
        need(0)
        return [("sll", ["$zero", "$zero", "0"])]
    if op == "move":  # move rd, rs
        need(2)
        return [("add", [args[0], args[1], "$zero"])]
    if op == "not":  # not rd, rs
        need(2)
        return [("nor", [args[0], args[1], "$zero"])]
    if op == "clear":  # clear rd
        need(1)
        return [("add", [args[0], "$zero", "$zero"])]
    if op == "b":  # b label
        need(1)
        return [("beq", ["$zero", "$zero", args[0]])]
    if op in ("beqz", "bnez"):  # beqz rs, label
        need(2)
        return [(op[:3], [args[0], "$zero", args[1]])]
    if op in ("blt", "bge", "bgt", "ble"):  # blt rs, rt, label
        need(3)
        rs, rt, label = args
        a, b = (rs, rt) if op in ("blt", "bge") else (rt, rs)
        branch = "bne" if op in ("blt", "bgt") else "beq"
        return [("slt", ["$at", a, b]), (branch, ["$at", "$zero", label])]
    if op == "la":  # la rt, label  (always 2 instructions)
        need(2)
        rt, expr = args
        return [("lui", [rt, f"%hi({expr})"]), ("xori", [rt, rt, f"%lo({expr})"])]
    if op == "li":  # li rt, value
        need(2)
        rt, expr = args
        try:
            v = eval_expr(expr, symbols)
        except UndefinedSymbol:
            # value not known yet (label further ahead): use the long form
            return expand_pseudo("la", args, symbols)
        if not -(1 << 31) <= v <= 0xFFFFFFFF:
            raise AsmError(f"valor nao cabe em 32 bits: {v}")
        if -32768 <= v <= 32767:
            return [("addi", [rt, "$zero", str(v)])]
        if 0 <= v <= 0xFFFF:
            return [("xori", [rt, "$zero", str(v)])]
        v &= 0xFFFFFFFF
        out = [("lui", [rt, str(v >> 16)])]
        if v & 0xFFFF:
            # lui leaves the low 16 bits at 0, so xori works like ori
            out.append(("xori", [rt, rt, str(v & 0xFFFF)]))
        return out
    return None


# =============================================================================
# 4. First pass: addresses and labels
# =============================================================================
@dataclass
class Item:
    """Something to place in memory, with its address already fixed."""
    section: str  # 'text' or 'data'
    addr: int
    kind: str  # 'instr', 'word', 'byte', 'bytes'
    payload: object
    line: Line


def align_up(value, n):
    return (value + n - 1) // n * n


def first_pass(lines):
    symbols = {}
    items = []
    loc = {"text": 0, "data": 0}  # location counter of each section
    sec = "text"

    def define(name, value, line):
        if name in symbols:
            raise AsmError(f"simbolo definido duas vezes: '{name}'", line)
        if name.lower() in isa.INSTRUCTIONS:
            raise AsmError(f"'{name}' e uma mnemonica, nao pode ser label", line)
        symbols[name] = value

    for ln in lines:
        try:
            op, args = ln.op, ln.args
            is_instr = op and not op.startswith(".")

            # Instructions and .word are aligned to 4; a label on the same
            # line points to the already aligned address.
            if is_instr or op == ".word":
                loc[sec] = align_up(loc[sec], 4)
            for label in ln.labels:
                define(label, loc[sec], ln)
            if not op:
                continue

            if is_instr:
                if sec != "text":
                    raise AsmError(f"instrucao '{op}' fora de .text")
                real = expand_pseudo(op, args, symbols)
                if real is None:
                    if op not in isa.INSTRUCTIONS:
                        raise AsmError(f"instrucao desconhecida: '{op}'")
                    real = [(op, args)]
                for name, ops in real:
                    items.append(Item(sec, loc[sec], "instr", (name, ops), ln))
                    loc[sec] += 4

            elif op in (".text", ".data"):
                sec = op[1:]
            elif op == ".globl":
                pass
            elif op in (".eqv", ".equ", ".set"):
                if len(args) != 2:
                    raise AsmError(f"{op} NOME, valor")
                define(args[0], eval_expr(args[1], symbols), ln)
            elif op == ".org":
                new = eval_expr(args[0], symbols)
                if new < loc[sec]:
                    raise AsmError(f".org 0x{new:X} recua (ja estamos em 0x{loc[sec]:X})")
                loc[sec] = new
            elif op == ".align":  # .align n -> multiple of 2^n
                loc[sec] = align_up(loc[sec], 1 << eval_expr(args[0], symbols))
            elif op == ".space":
                n = eval_expr(args[0], symbols)
                items.append(Item(sec, loc[sec], "bytes", bytes(n), ln))
                loc[sec] += n
            elif op == ".word":
                items.append(Item(sec, loc[sec], "word", args, ln))
                loc[sec] += 4 * len(args)
            elif op == ".byte":
                items.append(Item(sec, loc[sec], "byte", args, ln))
                loc[sec] += len(args)
            elif op in (".ascii", ".asciiz"):
                data = b"".join(parse_string(a) for a in args)
                if op == ".asciiz":
                    data += b"\0"
                items.append(Item(sec, loc[sec], "bytes", data, ln))
                loc[sec] += len(data)
            else:
                raise AsmError(f"diretiva desconhecida: '{op}'")
        except (AsmError, isa.IsaError) as e:
            raise AsmError(str(e), ln) from None

    return symbols, items


# =============================================================================
# 5. Second pass: encoding
# =============================================================================
MEM_RE = re.compile(r"^(.*)\(\s*(\$\w+)\s*\)$")


def parse_operand(kind, text, symbols):
    """Converts the text of an operand into the value isa.encode() expects."""
    if kind in ("rd", "rs", "rt"):
        return isa.reg_number(text)
    if kind == "mem":  # offset(base)
        m = MEM_RE.match(text.strip())
        if not m:
            raise AsmError(f"operando de memoria esperado, offset($reg): '{text}'")
        offset = eval_expr(m.group(1), symbols) if m.group(1).strip() else 0
        return (offset, isa.reg_number(m.group(2)))
    if kind == "cp0":  # $14 or 14
        try:
            return int(text.strip().lstrip("$"), 0)
        except ValueError:
            raise AsmError(f"registo do CP0 invalido: '{text}'") from None
    return eval_expr(text, symbols)  # immediates, branch, jump


def second_pass(items, symbols):
    images = {"text": bytearray(), "data": bytearray()}
    listing = []  # (section, address, bytes, Item)

    for it in items:
        try:
            if it.kind == "instr":
                name, args = it.payload
                d = isa.INSTRUCTIONS[name]
                if len(args) != len(d.operands):
                    raise AsmError(f"'{name}' espera {len(d.operands)} operando(s), recebeu {len(args)}")
                values = [parse_operand(k, a, symbols) for k, a in zip(d.operands, args)]
                data = isa.encode(name, values, pc=it.addr).to_bytes(4, "little")
            elif it.kind == "word":
                data = b"".join((eval_expr(a, symbols) & 0xFFFFFFFF).to_bytes(4, "little") for a in it.payload)
            elif it.kind == "byte":
                data = b"".join((eval_expr(a, symbols) & 0xFF).to_bytes(1, "little") for a in it.payload)
            else:
                data = it.payload
        except (AsmError, isa.IsaError) as e:
            raise AsmError(str(e), it.line) from None

        end = it.addr + len(data)
        if end > MEM_SIZE[it.section]:
            raise AsmError(f"passa o fim da memoria de {it.section} (0x{MEM_SIZE[it.section]:X} bytes)", it.line)
        img = images[it.section]
        if len(img) < end:
            img.extend(bytes(end - len(img)))
        img[it.addr:end] = data
        listing.append((it.section, it.addr, data, it))

    return images, listing


# =============================================================================
# 6. Output
# =============================================================================
def words_of(img):
    """bytearray -> list of words (little-endian, as load_ext.v expects)."""
    img = img + bytes(-len(img) % 4)
    return [int.from_bytes(img[i:i + 4], "little") for i in range(0, len(img), 4)]


def write_mem(path, img, section, source):
    lines = [f"// {section} gerado por assembler.py a partir de {source}"]
    for i, w in enumerate(words_of(img)):
        comment = isa.decode(w, pc=4 * i) if section == "text" else ""
        lines.append(f"{w:08X} // 0x{4 * i:04X} {comment}".rstrip())
    Path(path).write_text("\n".join(lines) + "\n")


def format_listing(listing, symbols):
    out = []
    for sec, addr, data, it in listing:
        if it.kind == "instr":
            w = int.from_bytes(data, "little")
            out.append(f"{sec[0]} {addr:04X}  {w:08X}  {isa.decode(w, pc=addr):<28} | {it.line.num:4}: {it.line.text.strip()}")
        else:
            hexdata = data[:8].hex(" ") + (" ..." if len(data) > 8 else "")
            out.append(f"{sec[0]} {addr:04X}  {hexdata:<38} | {it.line.num:4}: {it.line.text.strip()}")
    out.append("")
    out.append("Simbolos:")
    for name, value in sorted(symbols.items(), key=lambda kv: kv[1]):
        out.append(f"  {name:<20} 0x{value & 0xFFFFFFFF:08X}")
    return "\n".join(out) + "\n"


def assemble(source_text):
    """Assembly text -> (images, listing, symbols). Also used by the tests."""
    lines = [parse_line(i, raw) for i, raw in enumerate(source_text.splitlines(), start=1)]
    symbols, items = first_pass(lines)
    images, listing = second_pass(items, symbols)
    return images, listing, symbols


def main():
    ap = argparse.ArgumentParser(description="Assembler para o MIPS32 do projeto")
    ap.add_argument("source", help="ficheiro .asm")
    ap.add_argument("-o", "--output", help="ficheiro IMEM (por omissao <source>.mem)")
    ap.add_argument("-d", "--data", help="ficheiro DMEM (por omissao <source>_data.mem)")
    ap.add_argument("-l", "--listing", help="escreve a listagem neste ficheiro ('-' = ecra)")
    args = ap.parse_args()

    src = Path(args.source)
    try:
        images, listing, symbols = assemble(src.read_text())
    except AsmError as e:
        where = f"{src}:{e.line.num}" if e.line else str(src)
        print(f"{where}: erro: {e}", file=sys.stderr)
        if e.line:
            print(f"    {e.line.text.strip()}", file=sys.stderr)
        sys.exit(1)

    text_out = args.output or src.with_suffix(".mem")
    write_mem(text_out, images["text"], "text", src.name)
    print(f"{text_out}: {len(words_of(images['text']))} palavras de instrucoes")
    if images["data"] or args.data:
        data_out = args.data or src.with_name(src.stem + "_data.mem")
        write_mem(data_out, images["data"], "data", src.name)
        print(f"{data_out}: {len(words_of(images['data']))} palavras de dados")

    if args.listing:
        text = format_listing(listing, symbols)
        if args.listing == "-":
            print(text, end="")
        else:
            Path(args.listing).write_text(text)


if __name__ == "__main__":
    main()
