# Control Unit, ALU and Next-PC Logic: Design Notes (Rev 3 ISA)

**Date:** 2026-10-28 · **Spec:** [`project_spec_rev3.md`](project_spec_rev3.md) (Revision 3)

This document explains the three modules written for the Rev 3 ISA, their testbenches,
and the design decisions behind them.

| File | What it is |
|---|---|
| [`rtl/alu.v`](../rtl/alu.v) | ALU (spec §7) |
| [`rtl/control_unit.v`](../rtl/control_unit.v) | Control Unit, including the branch condition (spec §6, §6.1) |
| [`rtl/next_pc.v`](../rtl/next_pc.v) | Next-PC / jump logic (spec §6.2) |
| [`sim/tb_alu.v`](../sim/tb_alu.v) | ALU testbench |
| [`sim/tb_control_unit.v`](../sim/tb_control_unit.v) | Control Unit testbench |
| [`sim/tb_next_pc.v`](../sim/tb_next_pc.v) | Next-PC testbench + branch/jump path test (CU + ALU + next_pc) |

---

## 1. What changed from Rev 2

| Area | Rev 2 | Rev 3 | Effect on the RTL |
|---|---|---|---|
| Group instructions | `eret`, `ori`, `andi`, `sltu`, `lui`, … | `bgez`, `bgtz`, `lb`, `xori`, `nor`, `mfc0`, `di`, `ei` | CU decode rewritten |
| `lui` | group extension | class ISA | none (same encoding) |
| ALU code `1001` | SLTU | reserved | SLTU removed from the ALU |
| Interrupt return | `eret` (PCSrc = EPC) | `mfc0 $k0,$14` → `ei` → `jr $k0` | EPC PC source removed; `PCSrc = 100` is now the interrupt vector |
| Write-back | 3 sources | 4 sources (`11` = EPC, for `mfc0`) | `WBSrc = 11` used |
| Loads | `lw` only | `lw`, `lb` (little-endian) | new `o_load_byte` |
| Branches | `beq`, `bne` (datapath chose taken/not taken with `o_branch_ne`) | + `bgez`, `bgtz`; **CU decides** taken/not taken | `o_branch_ne` removed; new inputs `i_zero`, `i_rs_neg` |

---

## 2. ALU (`rtl/alu.v`)

### 2.1 Interface

| Port | Width | Meaning |
|---|---|---|
| `i_a` | 32 | rs |
| `i_b` | 32 | rt or extended immediate |
| `i_shamt` | 5 | `instr[10:6]` |
| `i_ctrl` | 4 | ALUCtrl from the CU |
| `o_y` | 32 | result |
| `o_zero` | 1 | `o_y == 0` |

### 2.2 Operations

| ALUCtrl | Op | Result | Used by |
|---|---|---|---|
| `0000` | AND | `A & B` | and |
| `0001` | OR | `A \| B` | or |
| `0010` | ADD | `A + B` | add, addi, lw, lb, sw |
| `0011` | XOR | `A ^ B` | xor, xori |
| `0100` | SLL | `B << shamt` | sll |
| `0101` | SRL | `B >> shamt` | srl |
| `0110` | SUB | `A - B` | sub, beq, bne, bgtz |
| `0111` | SLT | signed `A < B` | slt |
| `1000` | NOR | `~(A \| B)` | nor |
| `1001` | – | reserved (old SLTU) → `0` | – |
| `1010` | LUI | `B[15:0] << 16` | lui |
| `1011`–`1111` | – | reserved → `0` | – |

### 2.3 Design decisions

**One shared adder (spec §8.3).** ADD, SUB and SLT all use one 32-bit adder.
SUB is computed as `A + ~B + 1`: when `sub_en = 1`, B is inverted and the `+1` comes in as
the carry-in. Synthesis confirms this: the ALU uses 8 `CARRY4` blocks, which is exactly one
32-bit carry chain.

**SLT without an overflow bug.** The naive version, "A < B if the sign of A − B is 1", is wrong
when A − B overflows. For example, `0x80000000 − 1 = 0x7FFFFFFF` is positive, but
`0x80000000` (the most negative number) is clearly less than 1. The ALU uses this rule:

```verilog
lt_signed = (i_a[31] != i_b[31]) ? i_a[31]   // different signs: the negative one is smaller
                                 : sum[31];  // same signs: A - B cannot overflow
```

**LUI is written as `{i_b[15:0], 16'b0}`**, not `i_b << 16`. The two are equal, because the
CU zero-extends the immediate for `lui`. This form makes it obvious that only the low half of B
is used and that it is just wiring, with no shifter.

**Reserved codes give 0.** This includes `1001` (old SLTU). The CU never produces these codes;
the default exists for safety and to avoid latches.

**`o_zero` is computed from `o_y`** (not from the adder only), so it is valid for every
operation. `beq`, `bne` and `bgtz` use it with SUB.

### 2.4 Changes from the previous version

- SLTU removed; `1001` is now reserved, as Rev 3 says.
- The adder is 32 bits instead of 33. The carry-out was only needed by SLTU.
- Header comment with the full operation table, so the file explains itself.

---

## 3. Control Unit (`rtl/control_unit.v`)

### 3.1 Interface

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `i_opcode` | in | 6 | `instr[31:26]` |
| `i_rs` | in | 5 | `instr[25:21]` (COP0 decode) |
| `i_rt` | in | 5 | `instr[20:16]` (**new**: REGIMM `bgez` and `bgtz` decode) |
| `i_rd` | in | 5 | `instr[15:11]` (COP0 decode) |
| `i_funct` | in | 6 | `instr[5:0]` (R-type funct; COP0 `sel = [2:0]`, `sc = [5]`) |
| `i_zero` | in | 1 | **new**: ALU result is 0 |
| `i_rs_neg` | in | 1 | **new**: `rs[31]`, taken directly from register-file port A |
| `i_irq_take` | in | 1 | **new**: Phase 2 interrupt taken; 0 in Phase 1 |
| `o_reg_write` | out | 1 | write the register file |
| `o_reg_dst` | out | 2 | `00` rt, `01` rd, `10` $31 |
| `o_alu_src` | out | 1 | `0` rt, `1` extended immediate |
| `o_alu_ctrl` | out | 4 | ALU operation |
| `o_ext_op` | out | 1 | `0` zero-extend, `1` sign-extend |
| `o_mem_read` | out | 1 | DMEM read (lw, lb) |
| `o_mem_write` | out | 1 | DMEM write (sw) |
| `o_load_byte` | out | 1 | **new**: `0` lw, `1` lb |
| `o_wb_src` | out | 2 | `00` ALU, `01` load-ext, `10` PC+4, `11` EPC |
| `o_pc_src` | out | 3 | see §4 |
| `o_ie_we` | out | 1 | di / ei write IE |
| `o_ie_val` | out | 1 | value written to IE (`instr[5]`) |

Removed: `o_branch_ne`. The datapath no longer needs to know which branch it is, because
the CU now decides "taken or not" (spec §6.1).

### 3.2 Structure: three blocks

The old CU was one big `always` block. The new one has three parts, each with a single job:

```
 instruction fields ──► [1. Decode] ──► control word (except write enables and PCSrc)
                              │
                              ├── dec_branch ──► [2. Branch condition] ◄── i_zero, i_rs_neg
                              │                         │ branch_taken
                              └── dec_pc_src ──► [3. PC select + cancel] ◄── i_irq_take
                                                        │
                                       o_pc_src, o_reg_write, o_mem_read,
                                       o_mem_write, o_ie_we
```

1. **Decode** (`always @(*)`): looks **only** at the instruction fields. It produces the control
   word, plus two internal signals: `dec_branch` (which branch condition to test) and
   `dec_pc_src` (the PC source when no branch is taken).
2. **Branch condition** (`always @(*)`): spec §6.1, written as a `case` on `dec_branch`.
3. **PC select and interrupt cancellation** (`always @(*)` + four `assign`s).

Why split it:
- **The control word depends only on the instruction.** Only `o_pc_src` and the four write/read
  enables depend on status signals. This is exactly what a future pipeline needs (spec §12): the
  decode part moves to ID unchanged, and the status-dependent part sits where branches and
  interrupts are resolved.
- **No false combinational loop.** `i_zero` comes from the ALU, and the ALU is controlled by
  `o_alu_ctrl`. In a single block, the simulator re-evaluates `o_alu_ctrl` whenever `i_zero`
  changes, and some lint tools report a loop. With the split, `o_alu_ctrl` structurally cannot
  depend on `i_zero`.
- Each block still follows the rules: defaults at the top, `default:` in every `case`, `=` only,
  one block per signal.

### 3.3 Control word per instruction

| Instruction | RegWrite | RegDst | ALUSrc | ExtOp | MemRead | MemWrite | LoadByte | WBSrc | PCSrc | ALUCtrl | IEWrite | IEVal |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| add sub and or xor nor slt | 1 | rd | reg | (1) | 0 | 0 | (0) | ALU | PC+4 | op | 0 | (0) |
| sll, srl | 1 | rd | reg | (1) | 0 | 0 | (0) | ALU | PC+4 | SLL/SRL | 0 | (0) |
| addi | 1 | rt | imm | sign | 0 | 0 | (0) | ALU | PC+4 | ADD | 0 | (0) |
| xori | 1 | rt | imm | zero | 0 | 0 | (0) | ALU | PC+4 | XOR | 0 | (0) |
| lui | 1 | rt | imm | zero | 0 | 0 | (0) | ALU | PC+4 | LUI | 0 | (0) |
| lw | 1 | rt | imm | sign | 1 | 0 | 0 | Mem | PC+4 | ADD | 0 | (0) |
| lb | 1 | rt | imm | sign | 1 | 0 | 1 | Mem | PC+4 | ADD | 0 | (0) |
| sw | 0 | (rt) | imm | sign | 0 | 1 | (0) | (ALU) | PC+4 | ADD | 0 | (0) |
| beq, bne, bgez, bgtz | 0 | (rt) | reg | sign | 0 | 0 | (0) | (ALU) | **branch if taken** | SUB | 0 | (0) |
| j | 0 | (rt) | (reg) | (1) | 0 | 0 | (0) | (ALU) | jump | (ADD) | 0 | (0) |
| jal | 1 | $31 | (reg) | (1) | 0 | 0 | (0) | PC+4 | jump | (ADD) | 0 | (0) |
| jr | 0 | (rt) | (reg) | (1) | 0 | 0 | (0) | (ALU) | rs | (ADD) | 0 | (0) |
| mfc0 rt,$14 | 1 | rt | (reg) | (1) | 0 | 0 | (0) | EPC | PC+4 | (ADD) | 0 | (0) |
| di / ei | 0 | (rt) | (reg) | (1) | 0 | 0 | (0) | (ALU) | PC+4 | (ADD) | 1 | `instr[5]` |

Values in parentheses are don't-cares. The RTL drives them with the block's default value.

`bgez` does not use the ALU result, but it still gets `ALUCtrl = SUB` like the other branches.
This costs nothing and keeps all branches identical in the decoder.

### 3.4 Decoding the fixed fields

Unknown encodings must behave as `nop` (spec §6). Besides opcode and funct, the CU checks the
fixed fields listed in spec §6:

| Instruction | Condition | Otherwise |
|---|---|---|
| `bgez` | `opcode = 01` **and** `rt = 00001` | nop (e.g. `bltz` rt=0, `bgezal` rt=17) |
| `bgtz` | `opcode = 07` **and** `rt = 00000` | nop |
| `mfc0` | `opcode = 10`, `rs = 00000`, `rd = 14`, `sel = 000` | nop (e.g. `mfc0 $t0,$12`, `mtc0`) |
| `di`/`ei` | `opcode = 10`, `rs = 01011`, `rd = 01100` | nop |

The CU checks exactly the fields that spec §6 lists, no more. For example, it does not check
that `shamt = 0` on `add`. The assembler guarantees that unused bits are 0, and checking every
unused bit would only add LUTs.

### 3.5 Branch condition (spec §6.1)

```verilog
case (dec_branch)
    BR_BEQ:  branch_taken =  i_zero;              // rs - rt == 0
    BR_BNE:  branch_taken = ~i_zero;
    BR_BGEZ: branch_taken = ~i_rs_neg;            // rs[31] == 0  ⇔  rs >= 0
    BR_BGTZ: branch_taken = ~i_rs_neg & ~i_zero;  // rs >= 0 and rs != 0
    default: branch_taken = 1'b0;
endcase
```

- **`bgtz`**: its `rt` field is `00000`, so ALU port B reads `$zero` and the ALU computes
  `rs − 0 = rs`. So `i_zero` means "rs == 0", and `bgtz` is "not negative and not zero". No
  comparator is added; the existing SUB and `o_zero` are reused.
- **`bgez`**: its `rt` field is `00001`, so port B reads `$at`, whose value is random. That is why
  `bgez` uses **only** `i_rs_neg` and never `i_zero`. The path testbench proves this by giving
  `$at` several different values (§6.3).
- **`i_rs_neg` comes from the register file, not the ALU.** It is available earlier (no adder
  delay), and it stays correct even when port B holds garbage (`bgez`).

### 3.6 Interrupt cancellation (Phase 2 ready)

Spec §10.2: when an interrupt is taken, the instruction at PC is cancelled and re-executed
after the return. The CU implements this now:

```verilog
o_pc_src    = i_irq_take ? PC_VECTOR : (branch_taken ? PC_BRANCH : dec_pc_src);
o_reg_write = dec_reg_write & ~i_irq_take;
o_mem_read  = dec_mem_read  & ~i_irq_take;
o_mem_write = dec_mem_write & ~i_irq_take;
o_ie_we     = dec_ie_we     & ~i_irq_take;
```

Decisions:
- **Why now, if interrupts are Phase 2?** The spec lists `i_irq_take` as a "Phase 2" CU input.
  Adding it now means Phase 2 needs **no change to `control_unit.v` or `cpu.v`**. Phase 2 only
  drives the real `i_irq` from the interrupt controller in `soc.v` (guideline: "Phase 2 features
  pluggable in `soc.v`"). In Phase 1 `i_irq = 0`, so `cop0.v` gives `irq_take = 0`, and Vivado
  removes the extra gates.
- **MemRead is also cancelled.** The spec mentions RegWrite, MemWrite and IE writes. MemRead is
  cancelled as well, because in Phase 2 a read from an MMIO peripheral can have side effects
  (for example, reading a UART data register pops the receive FIFO). A cancelled `lw` that is
  executed again would otherwise consume two bytes.
- The interrupt vector wins over any branch or jump. The cancelled branch or jump is re-executed
  after the return, so nothing is lost (spec §10.2: "Branches and jumps need no special handling").

### 3.7 Other improvements over the previous version

- Every magic number is now a named `localparam` (`DST_RD`, `WB_EPC`, `PC_JR`, `RT_BGEZ`, `RD_EPC`, …).
- Opcodes are written in hex (`6'h2B`) to match the tables in the spec, which makes review easier.
- Removed `andi`, `ori`, `sltu`, `eret`.

---

## 4. Next-PC / jump logic (`rtl/next_pc.v`)

### 4.1 Interface

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `IRQ_VECTOR` | parameter | 32 | interrupt vector address (default `0x0000_0004`, placeholder) |
| `i_pc` | in | 32 | current PC |
| `i_imm` | in | 16 | `instr[15:0]`, branch offset in words |
| `i_index` | in | 26 | `instr[25:0]`, jump index |
| `i_rs_data` | in | 32 | value of register rs (target of `jr`) |
| `i_pc_src` | in | 3 | PCSrc from the CU |
| `o_next_pc` | out | 32 | value loaded into the PC at the next clock edge |
| `o_pc_plus4` | out | 32 | PC + 4 (also the `jal` link value, `WBSrc = 10`) |

### 4.2 Function

| PCSrc | Next PC | Used by |
|---|---|---|
| `000` | PC + 4 | sequential |
| `001` | (PC+4) + (SignExt(imm) << 2) | beq, bne, bgez, bgtz (when taken) |
| `010` | {(PC+4)[31:28], index, 00} | j, jal |
| `011` | rs | jr |
| `100` | `IRQ_VECTOR` | interrupt entry (Phase 2) |
| `101`–`111` | PC + 4 | reserved |

### 4.3 Design decisions

- **The branch decision is not made here.** The CU decides (spec §6.1), so for `next_pc`,
  `PCSrc = 001` always means "go to the branch target". This keeps `next_pc` a plain multiplexer
  with no knowledge of instructions, and the CU/datapath interface has a single PC-control
  signal (`PCSrc`) instead of `PCSrc` + `branch_ne` + flags.
- **`next_pc` takes the raw 16-bit immediate** and does its own sign extension and `<< 2`. Both
  are only wiring, so they cost no logic. This way the branch target never depends on `ExtOp`,
  even though `ExtOp` happens to be "sign" for branches. The spec lists `extend.v` and
  `shift_left_two.v` as separate modules, but for the branch offset they would only rename wires.
- **Jumps use (PC+4)[31:28], not PC[31:28]**, as MIPS32 defines. They only differ when PC is the
  last word of a 256 MB region. The testbench checks that case (`PC = 0x0FFFFFFC`).
- **`jr` passes rs unchanged**, with no forced alignment. The ISA says `PC = rs`, and the IMEM
  ignores the two low address bits (`addr_w = i_addr[AW+1:2]`). `refsim.py` must do the same so
  that PC traces match.
- **`IRQ_VECTOR` is a parameter.** Spec §13 has not fixed the vector address yet. The default
  `0x0000_0004` assumes the layout `0x0: j main`, `0x4: handler`. When Phase 2 fixes the address,
  only the parameter changes.
- **Reserved PCSrc codes go to PC + 4** (the safe default, same as the CU's `nop` policy).
- **Synthesis:** 90 LUTs + 16 `CARRY4` (two 32-bit adders: PC+4 and the branch target).

### 4.4 How it connects in the datapath

`next_pc.v` is a datapath submodule (spec §9.5). The future `datapath.v` should wire it like this:

```verilog
next_pc #(.IRQ_VECTOR(IRQ_VECTOR)) u_next_pc (
    .i_pc       (pc_r),            // from pc_reg.v
    .i_imm      (instr[15:0]),
    .i_index    (instr[25:0]),
    .i_rs_data  (rs_data),         // register-file port A
    .i_pc_src   (i_pc_src),        // from the CU, through cpu.v
    .o_next_pc  (next_pc),         // into pc_reg.v (loaded when i_en)
    .o_pc_plus4 (pc_plus4)         // write-back mux input 10 (jal)
);

assign o_rs_neg = rs_data[31];     // status signal to the CU
```

---

## 5. Signals between the CU and the datapath (Rev 3)

All signals are named ports (spec §2.3):

```
                 control word
   ┌──────────┐ ─────────────────────────────────────────────► ┌──────────────┐
   │          │  o_reg_write o_reg_dst o_alu_src o_alu_ctrl     │              │
   │ control  │  o_ext_op o_mem_read o_mem_write o_load_byte    │   datapath   │
   │  unit    │  o_wb_src o_pc_src o_ie_we o_ie_val             │ (alu, next_pc│
   │          │ ◄───────────────────────────────────────────── │  cop0, ...)  │
   └──────────┘  i_zero  i_rs_neg  i_irq_take   status          └──────────────┘
        ▲
        │ i_opcode i_rs i_rt i_rd i_funct   (instruction fields)
```

---

## 6. Testbenches

All three are self-checking: they print one `PASS`/`FAIL` line per test and end with
`ALL TESTS PASSED` or `SOME TESTS FAILED`. A failure prints the inputs, what was received and
what was expected.

### 6.1 `tb_alu.v` (66 checks)

1. **Edge cases** (44 named): every operation, including add/sub overflow wrap-around, SLT
   where A − B overflows (`0x80000000 < 1`), shifts by 0 and 31, SRL being logical, NOT with
   `nor rs, $zero`, `xori 0xFFFF` (zero-extended), the address of the last DMEM byte for `lb`,
   the three `bgtz` cases (rs − 0), reserved codes including `1001`.
2. **lui + xori sequences** from the spec test plan: `0x12345678`, `0x80008000` (low half
   ≥ `0x8000` must not corrupt the high half) and `0xFFFF0000`. The first result is fed back as
   A, like in the CPU.
3. **Corner matrix**: ADD, SUB, SLT on every pair of 10 corner values (0, 1, −1, MAX, MIN,
   MIN+1, MAX−1, −2, `0x8000`, `0xFFFF`). This is where overflow bugs hide.
4. **Random**: 20,000 vectors per operation and 1,000 per reserved code, against a reference
   model written with plain Verilog operators (`-`, `$signed <`, `* 0x10000`), so a bug in the
   RTL is not copied into the model.

### 6.2 `tb_control_unit.v` (67 checks)

1. **Every instruction of the ISA.** Each non-branch instruction is checked with all 4
   combinations of (`i_zero`, `i_rs_neg`), which proves its control word does not depend on the
   status signals. The full 19-bit control word is compared, with don't-cares (`x`) where the
   spec allows them.
2. **Branches**: the taken/not-taken result for all 4 status combinations for `beq`, `bne`,
   `bgez`, `bgtz` (forward and backward) and `b label`.
3. **Interrupt cancellation**: with `i_irq_take = 1`, 13 instructions (ALU, `lw`, `lb`, `sw`,
   branches, jumps, COP0, an invalid word) must have no writes, no memory read, and
   `PCSrc = 100`.
4. **Outside the ISA → nop**: `eret`, `ori`, `andi`, `addiu`, `sb`, `lbu`, `sltu`, `jalr`, `sra`,
   `bltz`, `bgezal`, `blez`, `bgtz` with rt≠0, `mfc0 $12`, `mfc0` with sel≠0, `mtc0`,
   `di`/`ei` with the wrong rd.
5. **Sweeps**:
   - every unused opcode (50 × 32 random bodies),
   - every unused R-type funct (54 × 32),
   - all 32 `rt` values for REGIMM and for opcode `07`,
   - **every** COP0 `rs × rd × sel × sc` combination (16,384 words, with random rt and other
     bits). Only the exact `mfc0`/`di`/`ei` encodings may do something.

### 6.3 `tb_next_pc.v` (68 checks)

1. **`next_pc` alone** (20 named): every PCSrc code, wrap-around at `0xFFFFFFFC`, maximum
   forward and backward branch offsets, "branch to itself" (offset −1), the jump region taken
   from PC+4, `jr $k0 = 0`, unaligned `jr`, the vector (with a parameter override), reserved
   codes. `o_pc_plus4` is checked every time.
2. **Random**: 5,000 vectors per PCSrc code against a reference model.
3. **Branch/jump path** = `control_unit` + `alu` + `next_pc` wired like the datapath, with a
   register-file model (register 0 reads 0). This tests spec §6.1 end-to-end, starting from
   **register values**:
   - `bgez` and `bgtz` with rs = 0, 1, −1, `0x7FFFFFFF`, `0x80000000`, taken and not taken,
     forward and backward;
   - `bgez` with several `$at` values, including `$at = rs` (ALU result 0). This proves `bgez`
     ignores port B;
   - `bgtz rs=0` is not taken; the sll + bgez bit test;
   - `beq`/`bne`, `b label`, `j`, `jal` (and its PC+4 link), `jr $ra`, `end: j end`;
   - non-control instructions continue at PC+4;
   - the interrupt vector wins over a taken branch, `j`, `jr` and `add`.
4. **Random path**: 50,000 random instructions (biased toward branches and jumps, and toward
   rs = rt and rs ∈ {−1, 0, 1}) with random register values. The result is compared against a
   reference that uses `$signed` comparisons, which is independent of the `i_zero`/`i_rs_neg`
   method used in the RTL.

### 6.4 How to run

From Vivado (after `scripts/create_project.tcl`): in *Simulation Settings*, set the simulation
top to `tb_alu`, `tb_control_unit` or `tb_next_pc` and run the behavioural simulation.

From a terminal (Vivado `bin` on the PATH; run it in a scratch folder so `xsim.dir/` does not
land in the repo):

```bash
xvlog rtl/alu.v rtl/control_unit.v rtl/next_pc.v sim/tb_next_pc.v
xelab tb_next_pc -s tb_next_pc_snap
xsim tb_next_pc_snap -R
```

### 6.5 Results

| Testbench | Result (XSim 2024.2) |
|---|---|
| `tb_alu` | 66 passed, 0 failed |
| `tb_control_unit` | 67 passed, 0 failed |
| `tb_next_pc` | 68 passed, 0 failed |

**Checking the testbenches themselves (mutation test).** A testbench that never fails proves
nothing, so 9 bugs were planted in the RTL one at a time. **All 9 were caught:**

| Planted bug | Caught by |
|---|---|
| `bgtz` ignores `i_zero` (taken when rs = 0) | tb_control_unit (3 fails), tb_next_pc (2) |
| REGIMM `rt` not checked (`bltz` would act as `bgez`) | tb_control_unit (3) |
| `mfc0` `sel` not checked | tb_control_unit (2) |
| interrupt does not cancel MemRead | tb_control_unit (2) |
| `lb` without LoadByte | tb_control_unit (1) |
| jump region from PC instead of PC+4 | tb_next_pc (1) |
| branch offset zero-extended instead of sign-extended | tb_next_pc (8) |
| SLT ignores overflow (`sum[31]` only) | tb_alu (4) |
| LUI shifts by 15 | tb_alu (6) |

### 6.6 Lint and synthesis

- `verilator --lint-only -Wall`: no warnings on any of the three modules.
- Vivado 2024.2 out-of-context synthesis (`xc7z010clg400-1`): **0 latches** in all three.

| Module | LUTs | CARRY4 |
|---|---|---|
| `alu` | 343 | 8 (one shared adder) |
| `control_unit` | 46 | 0 |
| `next_pc` | 90 | 16 (PC+4 and branch target) |

Most of the ALU's LUTs are the two 32-bit barrel shifters (SLL, SRL).

---

## 7. Decisions beyond the spec, and open items

| # | Item | Status |
|---|---|---|
| 1 | `i_irq_take` added to the CU in Phase 1 (spec says Phase 2) | Done. No effect in Phase 1; avoids changing the CU in Phase 2 |
| 2 | Interrupt cancellation also clears MemRead | Done. Protects MMIO reads with side effects. Suggest adding it to spec §10.2 |
| 3 | CU split into decode / branch / PC-select blocks | Done. Same behaviour, cleaner for the pipeline |
| 4 | `next_pc` takes the raw `imm16` (own sign extension) | Done. Only wiring |
| 5 | `IRQ_VECTOR = 0x0000_0004` | **Placeholder**: fix it when the Phase 2 memory map is decided |
| 6 | ALU / PCSrc codes are `localparam`s copied in `alu.v`, `control_unit.v`, `next_pc.v` and the testbenches | A shared `` `include `` header would remove the copies, but it needs include paths in Vivado and XSim. The testbenches check that the copies agree (the path test connects the real CU to the real ALU) |
| 7 | `tools/isa.py` and `tools/refsim.py` do not exist yet | **To do.** The project rule says an ISA change updates `isa.py`, `control_unit.v`, `refsim.py` and the tests together. The opcode/funct/fixed-field tables in §3.4 and in `control_unit.v` are ready to be copied into `isa.py` |
| 8 | `docs/spec.md` is still Revision 2 and `CLAUDE.md` calls it authoritative | **To do.** Replace it with Rev 3 or point `CLAUDE.md` to `project_spec_rev3.md` |
| 9 | The user guideline mentions a "22-instruction ISA" | Out of date. The code follows Rev 3: 25 mnemonics / 24 encodings |
| 10 | `scripts/create_project.tcl` sets the simulation top to `control_unit` (a module, not a testbench) | Minor. Select the testbench by hand in Vivado, or change the script |
