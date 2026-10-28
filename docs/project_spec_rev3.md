# Project Spec: Single-Cycle MIPS32 SoC on FPGA & Toolchain

**Revision 3** (2026-10-28). Replaces revision 2.

**Changes from revision 2:**
- **Class-wide base ISA grows to 17 instructions:** `lui` moves from the group extensions into the class ISA.
- **Group extensions replaced.** `eret`, `ori`, `andi`, `addiu` and `sb` are assigned to other groups and are not available to us. New group set: **`bgez`, `bgtz`, `lb`, `xori`, `nor`, `mfc0`, `di`, `ei`** (8 mnemonics, 7 encodings). Removed from the group set: `eret`, `ori`, `andi`, `sltu`. The total stays at **25 mnemonics / 24 encodings**.
- **32-bit constants:** `lui` + `xori` (replaces `lui` + `ori`).
- **Interrupt return without `eret`:** fixed software sequence `mfc0 $k0, $14` → `ei` → `jr $k0`, made atomic by an **`ei` interrupt shadow** (new 1-bit state `ei_shadow_r`).
- **Software can read EPC** with `mfc0 rt, $14`. The write-back mux grows to **4 inputs** (`WBSrc` is 2 bits).
- **Byte order fixed: little-endian** (needed by `lb`). New load-extension unit and new control signal `LoadByte`.
- **New status signal `o_rs_neg`** (`rs[31]`) for `bgez`/`bgtz`; branch condition logic in the CU (§6.1).
- `PCSrc` stays **3 bits**; the EPC source is removed, code `100` is now the Phase 2 interrupt vector.
- ALU code `1001` (formerly SLTU) is now reserved.
- `swio` was considered and dropped (not MIPS32; peripherals use ordinary `lw`/`sw` through MMIO).

---

## 1. Overview and Project Structure

We are developing from scratch a 32-bit MIPS System-on-Chip (SoC) based on a Single-Cycle Harvard architecture in Verilog, together with a Python toolchain: an Assembler, a reference instruction-set simulator (golden model), and an automated test runner driving the Vivado simulator.

**Course context:** *Projecto de Sistemas Dedicados*, Prof. Adriano Tavares (DEI, Universidade do Minho). The lecture material uses didactic processors (EC-1/EC-2, 32-bit VeSPA, 16-bit GR0040/XSoC) rather than MIPS, but the engineering methodology, RTL coding style and architectural trade-offs defined there apply to our MIPS implementation.

**Final goal:** a bare-metal, interrupt-driven microcontroller-style SoC that controls peripherals through memory-mapped I/O.

Phases:

- **Phase 1 (current focus):** Implement the **Class-Wide Base ISA (17 instructions)** plus **8 group-selected extensions (25 mnemonics, 24 encodings)** in Verilog, build the Python toolchain, and validate the processor through automated behavioural simulation in Vivado (XSim). Phase 1 includes the decode and datapath support for `mfc0`, `di`, `ei` (EPC, IE and `ei_shadow_r` registers, EPC write-back input). Current status: specification and datapath design.
- **Phase 2:** Memory-Mapped I/O (MMIO) map, peripheral bus with custom peripherals (e.g., GPIO, Timer, PWM, UART) and hardware interrupt support (single-vector, non-nested). Interrupt **entry** logic (IRQ sampling, writing EPC, jumping to the vector) and the interrupt controller are added in this phase. The interrupt return is the software sequence of §10.2.
- **Future:** pipelined version of the CPU (classic 5-stage). Phase 1/2 decisions must not prevent it (§12).

---

## 2. Design Methodology

Top-down hierarchical refinement. Each level is a formal contract that higher levels rely on and lower levels must satisfy.

### 2.1 Architectural Level (ISA)

The ISA (§4) and the MIPS32 ABI (§5) are a **strict formal contract** between software (assembler, test programs) and hardware (CPU).

- Encodings follow **MIPS32 Release 2–5** exactly, for compatibility with standard tools. (Release 6 is **not** used: it removed `addi` and re-encoded other instructions.) No custom (non-MIPS) instructions.
- **Unused instruction bits are always `0`** (e.g., `shamt = 00000` on non-shift R-type, `rs = 00000` on `sll`/`srl`/`lui`, `rt = rd = shamt = 0` on `jr`, `rt = 00000` on `bgtz`/`di`/`ei`, `instr[10:0] = 0` on `mfc0`). On `bgez`, `rt = 00001` is a fixed sub-opcode, not an operand.
- **Byte order: little-endian** (as in MARS). The byte at address `A` is bits `[8·A[1:0]+7 : 8·A[1:0]]` of word `A >> 2`.
- `add`, `sub`, `addi` do **not** raise overflow exceptions (they behave like `addu`/`subu`/`addiu`).
- **No branch/jump delay slots and no load delay slot**, now or in any future pipelined version.
- The opcode/funct table is defined **once** in `isa.py` (§11) and must match `control_unit.v`.

### 2.2 Behavioural / Functional Verification

- Test programs assembled by our Python assembler are loaded into IMEM from `.mem` files (`$readmemh` / XPM `MEMORY_INIT_FILE`).
- Trace outputs gated by `` `ifdef TRACE_PC `` and `` `ifdef TRACE_REGS ``.
- Final register state, DMEM snapshot, **EPC/IE**, and PC trace are compared automatically against the **Python reference simulator** (primary golden model), with **MARS** as an independent cross-check (§11.4). MARS supports every instruction of our ISA **except `di`/`ei`**.

### 2.3 RTL / Structural Level

`cpu.v` is **strictly split** into:

- **Control Unit:** purely combinational decoder.
- **Datapath:** PC, register file, ALU, extenders, load-extension unit, multiplexers, EPC, IE, `ei_shadow_r`.

They communicate **only** through explicit, named ports:

- **Control Word** (CU → Datapath): `RegWrite`, `RegDst[1:0]`, `ALUSrc`, `ExtOp`, `MemRead`, `MemWrite`, `LoadByte`, `WBSrc[1:0]`, `PCSrc[2:0]`, `ALUCtrl[3:0]`, `IEWrite`, `IEVal`.
- **Status Signals** (Datapath → CU): `o_zero`, `o_rs_neg` (`rs[31]`); in Phase 2, `irq_take` (= `i_irq && ie_r && !ei_shadow_r`).

---

## 3. Hardware Platform and Tools

- **FPGA board:** Digilent Zybo Z7-10 (`xc7z010clg400-1`): 17,600 LUTs | 35,200 flip-flops | 270 KB Block RAM. Board I/O: push-buttons, slide switches, LEDs. Only the Programmable Logic is used.
- **Clocking:** 125 MHz oscillator (pin `K17`, 8 ns constraint). A **Clocking Wizard (MMCM)** generates the **50 MHz** CPU clock. Clocks are never divided with logic.
- **Hardware IDE:** Xilinx Vivado, synthesizable Verilog-2001, XSim behavioural simulation.
- **Memories:** `xpm_memory_sprom` (IMEM) and `xpm_memory_spram` (DMEM), `MEMORY_PRIMITIVE("distributed")`, `READ_LATENCY_A(0)` (combinational reads for single-cycle). DMEM stays word-wide with a single write enable: the ISA has no byte stores, so no byte-write enables are needed.
- **Register file:** 32 × 32 bits, flip-flops or distributed RAM (asynchronous reads), never Block RAM.
- **Software:** Python 3 (toolchain), MARS (cross-check only).
- **Reference manual:** *MIPS32 Architecture For Programmers, Volume II-A* (MD00086), Release 2–5 edition (contains `MFC0`, `DI`, `EI`).

---

## 4. ISA Specification (25 mnemonics, 24 encodings)

### 4.1 Class-Wide Base ISA (17 instructions)

**R-Type** (`opcode = 6'h00`; `[31:26] opcode | [25:21] rs | [20:16] rt | [15:11] rd | [10:6] shamt | [5:0] funct`)

| # | Instr | funct | Semantics |
|---|---|---|---|
| 1 | `add rd, rs, rt` | `6'h20` | `rd = rs + rt` |
| 2 | `sub rd, rs, rt` | `6'h22` | `rd = rs - rt` |
| 3 | `and rd, rs, rt` | `6'h24` | `rd = rs & rt` |
| 4 | `or rd, rs, rt` | `6'h25` | `rd = rs \| rt` |
| 5 | `xor rd, rs, rt` | `6'h26` | `rd = rs ^ rt` |
| 6 | `slt rd, rs, rt` | `6'h2A` | `rd = ($signed(rs) < $signed(rt)) ? 1 : 0` |
| 7 | `sll rd, rt, shamt` | `6'h00` | `rd = rt << shamt` (`nop` = `0x00000000`) |
| 8 | `srl rd, rt, shamt` | `6'h02` | `rd = rt >> shamt` (logical) |
| 9 | `jr rs` | `6'h08` | `PC = rs` |

**I-Type** (`[31:26] opcode | [25:21] rs | [20:16] rt | [15:0] imm`)

| # | Instr | opcode | Semantics |
|---|---|---|---|
| 10 | `addi rt, rs, imm` | `6'h08` | `rt = rs + SignExt(imm)` |
| 11 | `lw rt, imm(rs)` | `6'h23` | `rt = MEM32[rs + SignExt(imm)]` (word-aligned) |
| 12 | `sw rt, imm(rs)` | `6'h2B` | `MEM32[rs + SignExt(imm)] = rt` (word-aligned) |
| 13 | `beq rs, rt, label` | `6'h04` | `if (rs == rt) PC = (PC + 4) + (SignExt(imm) << 2)` |
| 14 | `bne rs, rt, label` | `6'h05` | `if (rs != rt) PC = (PC + 4) + (SignExt(imm) << 2)` |
| 15 | `lui rt, imm` | `6'h0F` | `rt = imm << 16`; `rs = 00000` |

**J-Type** (`[31:26] opcode | [25:0] instr_index`)

| # | Instr | opcode | Semantics |
|---|---|---|---|
| 16 | `j label` | `6'h02` | `PC = {(PC + 4)[31:28], instr_index, 2'b00}` |
| 17 | `jal label` | `6'h03` | `$ra = PC + 4; PC = {(PC + 4)[31:28], instr_index, 2'b00}` |

### 4.2 Group-Selected Extensions (8 mnemonics, 7 encodings)

**R-Type** (`opcode = 6'h00`)

| # | Instr | funct | Semantics |
|---|---|---|---|
| 18 | `nor rd, rs, rt` | `6'h27` | `rd = ~(rs \| rt)` |

**I-Type**

| # | Instr | Encoding | Semantics |
|---|---|---|---|
| 19 | `xori rt, rs, imm` | opcode `6'h0E` | `rt = rs ^ ZeroExt(imm)` |
| 20 | `lb rt, imm(rs)` | opcode `6'h20` | `rt = SignExt(MEM8[rs + SignExt(imm)])` (any byte address) |
| 21 | `bgez rs, label` | opcode `6'h01` (REGIMM), `rt = 00001` | `if ($signed(rs) >= 0) PC = (PC + 4) + (SignExt(imm) << 2)` |
| 22 | `bgtz rs, label` | opcode `6'h07`, `rt = 00000` | `if ($signed(rs) > 0) PC = (PC + 4) + (SignExt(imm) << 2)` |

**COP0** (`opcode = 6'h10`; R-type-like layout, decoded by opcode, **not** inside the R-type case)

| # | Instr | Fields | Encoding | Semantics |
|---|---|---|---|---|
| 23 | `mfc0 rt, $14` | `010000 \| 00000 \| rt \| 01110 \| 00000000 \| sel=000` | e.g. `mfc0 $k0, $14` = `0x401A7000` | `rt = EPC` |
| 24 | `di` | `010000 \| 01011 \| rt=00000 \| 01100 \| 00000 \| sc=0 \| 00 \| 000` | `0x41606000` | `IE = 0` |
| 25 | `ei` | `010000 \| 01011 \| rt=00000 \| 01100 \| 00000 \| sc=1 \| 00 \| 000` | `0x41606020` | `IE = 1`; interrupt shadow on the next instruction |

Notes on COP0 instructions:
- `mfc0` is supported **only for EPC** (CP0 register 14, select 0). Other CP0 registers do not exist in our CPU; the assembler rejects them and the hardware decodes them as `nop`. There is no `mtc0`: software can read EPC but never write it.
- `di`/`ei` are one encoding (MFMC0) that differs only in bit 5 (`sc`); hardware: `IE ← instr[5]`.
- Real MIPS32 `di rt`/`ei rt` also copy Status into `rt`. **We only support `rt = $zero`** (the argument-less form), so that write is discarded and behaviour is identical to MIPS32. The assembler rejects `di rt`/`ei rt` with a non-zero `rt`.
- `di` takes effect **immediately**: no interrupt is taken after `di` executes (must also hold in a pipelined version, without an `ehb` barrier).
- **`ei` interrupt shadow:** interrupts are **not sampled on the instruction immediately after `ei`**. This makes the return sequence `ei` → `jr $k0` atomic (§10.2). MIPS32 does not guarantee that `ei` takes effect until an `ehb` executes, so a deterministic one-instruction delay is a valid implementation of the architecture, not a change to it.
- `mfc0`, `di` and `ei` write no memory and do not use the ALU; only `mfc0` writes a GPR.
- No privilege modes: the MIPS "Coprocessor Unusable" exception is not implemented.

### 4.3 Opcode Map Summary

| opcode | Instructions | Further decode |
|---|---|---|
| `6'h00` | R-type | `funct` |
| `6'h01` | `bgez` | `rt == 5'b00001` |
| `6'h02` / `6'h03` | `j` / `jal` | — |
| `6'h04` / `6'h05` | `beq` / `bne` | — |
| `6'h07` | `bgtz` | `rt == 5'b00000` |
| `6'h08` | `addi` | — |
| `6'h0E` | `xori` | — |
| `6'h0F` | `lui` | — |
| `6'h10` | COP0: `mfc0`, `di`, `ei` | `rs`, `rd`, `sel`, bit 5 (§6) |
| `6'h20` | `lb` | — |
| `6'h23` | `lw` | — |
| `6'h2B` | `sw` | — |

### 4.4 Rationale and Programming Idioms

Instructions **not available** to our group (assigned to other groups): `eret`, `ori`, `andi`, `addiu`, `sb`. The group set is built to reach the same goals without them.

- `lui` + `xori`: `lui` leaves the lower 16 bits at zero, so `xori` with a zero-extended immediate behaves exactly like `ori`. Any 32-bit constant takes two instructions, and the low half never corrupts the high half.
- `xori`: toggle bits with an immediate.
- `nor`: NOT (`nor rd, rs, $zero`) and clearing bits anywhere in the 32-bit word (with `and`).
- `bgez` / `bgtz`: one-instruction comparisons against zero (`≥ 0`, `> 0`; `< 0` and `≤ 0` by inverting the branch). With `sll`, `bgez` tests any single bit without a mask register. `bgtz` is the natural countdown-loop condition.
- `lb`: byte data (strings, UART characters, byte tables).
- `mfc0`: reads EPC for the interrupt return.
- `di` / `ei`: enable interrupts at boot, protect critical sections (data shared with the handler), and make the interrupt return atomic.
- `addiu` is not needed: our `addi` never traps.
- `sltu` was dropped: DMEM addresses (0–2 KB) and loop counters are small positive values, where `slt` is correct; MMIO addresses are used as fixed `lw`/`sw` offsets, never compared.

Bit-manipulation idioms without `andi`/`ori`:

| Task | Sequence |
|---|---|
| Load 32-bit constant | `lui rt, hi` ; `xori rt, rt, lo` |
| Test bit *k* | `sll $t0, $t1, 31-k` ; `bgez $t0, bit_is_clear` |
| Set bits | `or rd, rs, $mask` |
| Clear bits | `nor $t0, $mask, $zero` ; `and rd, rs, $t0` |
| Toggle low 16 bits | `xori rd, rs, imm` |
| NOT | `nor rd, rs, $zero` |

---

## 5. Register File (MIPS32 ABI)

| Name | No. | Use |
|---|---|---|
| `$zero` | 0 | Constant 0 (hardwired) |
| `$at` | 1 | Assembler temporary |
| `$v0`–`$v1` | 2–3 | Return values |
| `$a0`–`$a3` | 4–7 | Function arguments |
| `$t0`–`$t7` | 8–15 | Temporaries (caller-saved) |
| `$s0`–`$s7` | 16–23 | Saved registers (callee-saved) |
| `$t8`–`$t9` | 24–25 | Temporaries (caller-saved) |
| `$k0`–`$k1` | 26–27 | Reserved for the interrupt handler (**never used by main code**) |
| `$gp` | 28 | Global pointer |
| `$sp` | 29 | Stack pointer |
| `$fp` | 30 | Frame pointer |
| `$ra` | 31 | Return address (written by `jal`) |

- Address `5'b00000` reads `32'b0`; writes ignored.
- **2 asynchronous read ports** (`rs`, `rt`); **1 synchronous write port**, enabled by `i_reg_write && i_en`.
- **RegDst mux (3 inputs):** `rt`, `rd`, `5'd31`.
- **Write-data mux (4 inputs, `WBSrc[1:0]`):** `00` ALU result, `01` load-extension output (DMEM), `10` `PC + 4`, `11` EPC (`mfc0`). A 4:1 mux still fits in one LUT6 per bit.
- Registers are not reset (except optionally in simulation).

### 5.1 Special CPU State (COP0 subset)

| Register | Width | Reset | Written by | Read by |
|---|---|---|---|---|
| `epc_r` | 32 | `32'h0` | interrupt entry (Phase 2): `EPC ← PC` | `mfc0 rt, $14` |
| `ie_r` | 1 | `1'b0` | `ei` (1), `di` (0), interrupt entry (0) | interrupt logic (Phase 2) |
| `ei_shadow_r` | 1 | `1'b0` | set by `ei`, cleared by the next instruction | interrupt logic (Phase 2) |

- All three are updated only when `i_en = 1`.
- Software reads EPC with `mfc0`; it cannot write EPC (no `mtc0`) and cannot read IE (no Status register).
- Boot sequence: IE starts at 0; software enables interrupts with `ei` when ready.

---

## 6. Control Unit

Purely combinational (`always @(*)`), decoding `opcode`, `funct`, `rt` (REGIMM, `bgtz`), and for COP0 the `rs`/`rd`/`sel` fields and bit 5. All outputs default to safe values (no writes, `PCSrc = PC+4`, `IEWrite = 0`); every `case` has a `default:`. Unknown encodings behave as `nop`.

| Instruction | RegWrite | RegDst | ALUSrc | ExtOp | MemRead | MemWrite | LoadByte | WBSrc | PCSrc | IEWrite | IEVal |
|---|---|---|---|---|---|---|---|---|---|---|---|
| add, sub, and, or, xor, nor, slt | 1 | rd | reg | – | 0 | 0 | – | ALU | PC+4 | 0 | – |
| sll, srl | 1 | rd | reg | – | 0 | 0 | – | ALU | PC+4 | 0 | – |
| addi | 1 | rt | imm | sign | 0 | 0 | – | ALU | PC+4 | 0 | – |
| xori, lui | 1 | rt | imm | zero | 0 | 0 | – | ALU | PC+4 | 0 | – |
| lw | 1 | rt | imm | sign | 1 | 0 | 0 | Mem | PC+4 | 0 | – |
| lb | 1 | rt | imm | sign | 1 | 0 | 1 | Mem | PC+4 | 0 | – |
| sw | 0 | – | imm | sign | 0 | 1 | – | – | PC+4 | 0 | – |
| beq, bne | 0 | – | reg | sign | 0 | 0 | – | – | branch | 0 | – |
| bgez, bgtz | 0 | – | reg | sign | 0 | 0 | – | – | branch | 0 | – |
| j | 0 | – | – | – | 0 | 0 | – | – | jump | 0 | – |
| jal | 1 | $31 | – | – | 0 | 0 | – | PC+4 | jump | 0 | – |
| jr | 0 | – | – | – | 0 | 0 | – | – | rs | 0 | – |
| mfc0 | 1 | rt | – | – | 0 | 0 | – | EPC | PC+4 | 0 | – |
| di | 0 | – | – | – | 0 | 0 | – | – | PC+4 | 1 | 0 |
| ei | 0 | – | – | – | 0 | 0 | – | – | PC+4 | 1 | 1 |

- "–" = don't care, but the RTL still drives a defined default.
- `di`/`ei` share one decode case: `IEVal = instr[5]`.
- REGIMM decode: `opcode == 6'h01` and `rt == 5'b00001` → `bgez`; any other `rt` → `nop`.
- `bgtz` decode: `opcode == 6'h07` and `rt == 5'b00000`; any other `rt` → `nop`.
- COP0 decode: `opcode == 6'h10` and
  - `mfc0`: `rs == 5'b00000`, `rd == 5'd14` and `sel` (`instr[2:0]`) `== 3'b000`
  - `di`/`ei`: `rs == 5'b01011` and `rd == 5'b01100`
  - anything else → `nop`

### 6.1 Branch Condition

`PCSrc = branch` selects the branch target only when the branch is taken; otherwise PC+4. The CU computes the condition from the status signals:

```verilog
branch_taken = (is_beq  &  i_zero)   |
               (is_bne  & ~i_zero)   |
               (is_bgez & ~i_rs_neg) |
               (is_bgtz & ~i_rs_neg & ~i_zero);
```

- `beq`, `bne`, `bgtz` use ALU SUB with `ALUSrc = reg`. For `bgtz`, `rt = 00000`, so the B port reads `$zero`, the ALU computes `rs - 0`, and `o_zero = (rs == 0)`.
- `bgez` uses **only** `o_rs_neg`. Its `rt` field is `00001`, so the B port reads `$at` and `o_zero` is meaningless for it.
- `o_rs_neg` is `rs[31]` taken directly from register-file read port A (not from the ALU), so it is available early.

### 6.2 Next-PC Logic (PCSrc, 3 bits)

| PCSrc | Next PC | Used by |
|---|---|---|
| `000` | PC + 4 | sequential execution |
| `001` | (PC+4) + (SignExt(imm) << 2) | beq, bne, bgez, bgtz (if taken) |
| `010` | {(PC+4)[31:28], index, 00} | j, jal |
| `011` | rs | jr |
| `100` | interrupt vector | interrupt entry (Phase 2) |
| `101`–`111` | reserved | — |

- Phase 1 uses 4 PC sources; Phase 2 adds the vector as the 5th input without changing the encoding.

---

## 7. ALU

Combinational, 4-bit control, 10 operations, 6 free codes. Not used by `mfc0`/`di`/`ei`/`bgez`.

| ALUCtrl | Operation | Function | Used by |
|---|---|---|---|
| `0000` | AND | `A & B` | and |
| `0001` | OR | `A \| B` | or |
| `0010` | ADD | `A + B` | add, addi, lw, lb, sw |
| `0011` | XOR | `A ^ B` | xor, xori |
| `0100` | SLL | `B << shamt` | sll |
| `0101` | SRL | `B >> shamt` | srl |
| `0110` | SUB | `A - B` | sub, beq, bne, bgtz |
| `0111` | SLT | `A < B` (signed) | slt |
| `1000` | NOR | `~(A \| B)` | nor |
| `1001` | — | reserved (formerly SLTU) | — |
| `1010` | LUI | `B << 16` | lui |
| `1011`–`1111` | — | reserved | — |

- `o_zero = (o_y == 32'b0)`; `beq`/`bne`/`bgtz` reuse SUB and `o_zero`.
- Inputs: `i_a` (rs), `i_b` (rt or extended immediate), `i_shamt` (`instr[10:6]`), `i_ctrl[3:0]`. Outputs: `o_y[31:0]`, `o_zero`.

---

## 8. Verilog-2001 Coding Style & FPGA Synthesis Rules

### 8.1 Blocking vs. Non-Blocking
- `=` only in `always @(*)`; `<=` only in `always @(posedge i_clk)`; never mixed; one `always` block per signal.

### 8.2 Zero Unintended Latches
Every `always @(*)`: defaults for all outputs at the top, `default:` in every `case`, no undriven paths.

### 8.3 Resources & Timing
- ADD, SUB and branch comparison share one adder (SUB as `A + ~B + 1`).
- Zero-latency distributed-RAM memories.
- Critical path: PC → IMEM → register read → ALU → DMEM → **load extension** → write-back mux. The load-extension unit (byte-lane mux + sign extension) sits on this path and `lw` also passes through it. Check WNS ≥ 0 at 50 MHz; if it fails, lower the MMCM frequency.
- **Reset:** synchronous, active-high `i_rst`; PC ← `0`, EPC ← `0`, IE ← `0`, `ei_shadow_r` ← `0`.
- **Step/enable:** `i_en` gates **all** state updates (PC, register file, DMEM, EPC, IE, `ei_shadow_r`).
- Cost of the group extensions: 34 FFs (EPC + IE + `ei_shadow_r`), a 4-input write-back mux (one LUT6 per bit), the load-extension unit, a few LUTs of branch and COP0 decode.

### 8.4 Naming Conventions
`i_` inputs, `o_` outputs, `_r` registers, `u_` instances, `UPPER_CASE` parameters and macros.

---

## 9. Hardware Architecture & Verilog Hierarchy

1. **`soc.v` (top level):** ports `i_clk`, `i_rst`, `i_btn`, `i_sw`, `o_led`; Clocking Wizard, reset synchronizer, debouncing, step/enable logic; instantiates `u_imem`, `u_dmem`, `u_cpu`. In Phase 1 the CPU's `i_irq` is tied to `0`. Phase 2: address decoding, MMIO bus and interrupt controller live here, never in `cpu.v`.
2. **`instruction_memory.v` / `data_memory.v`:** byte-addressed externally, word-addressed internally (`addr_w = i_addr[AW+1:2]`, `AW = $clog2(DEPTH)`); IMEM `DEPTH = 256`, DMEM `DEPTH = 512`; DMEM drives `o_rd` only when `i_re`; DMEM always reads and writes whole words (byte selection for `lb` happens in the datapath). `lw`/`sw` are word-aligned only; `lb` may use any byte address. Keep parameterized (a pipeline may switch to Block RAM).
3. **`cpu.v`:** wires `control_unit` (`u_cu`) and `datapath` (`u_dp`) through the control word and status signals only.
4. **`control_unit.v`:** §6 table plus `o_alu_ctrl[3:0]`, `o_pc_src[2:0]`, `o_wb_src[1:0]`, `o_load_byte`, `o_ie_we`, `o_ie_val`; inputs `i_zero`, `i_rs_neg` (and `i_irq_take` in Phase 2).
5. **`datapath.v` and submodules:** `pc_reg.v`, `register_file.v`, `alu.v`, `extend.v`, `shift_left_two.v`, `mux2.v`, `mux3.v`, `mux4.v` (write-back), **`load_ext.v`**, **`next_pc.v`** (PC-source selection, §6.2), **`cop0.v`** (EPC, IE and `ei_shadow_r`).

`load_ext.v` reference behaviour (little-endian):

```verilog
always @(*) begin
  byte_sel = 8'b0;
  case (i_addr[1:0])
    2'b00:   byte_sel = i_rd[7:0];
    2'b01:   byte_sel = i_rd[15:8];
    2'b10:   byte_sel = i_rd[23:16];
    2'b11:   byte_sel = i_rd[31:24];
    default: byte_sel = 8'b0;
  endcase
  o_data = i_load_byte ? {{24{byte_sel[7]}}, byte_sel} : i_rd;
end
```

`cop0.v` reference behaviour:

```verilog
always @(posedge i_clk) begin
  if (i_rst) begin
    epc_r       <= 32'b0;
    ie_r        <= 1'b0;
    ei_shadow_r <= 1'b0;
  end else if (i_en) begin
    if (i_irq_take) begin                  // Phase 2: interrupt entry
      epc_r       <= i_pc;
      ie_r        <= 1'b0;
      ei_shadow_r <= 1'b0;
    end else begin
      if (i_ie_we)                         // di / ei
        ie_r <= i_ie_val;
      ei_shadow_r <= i_ie_we & i_ie_val;   // set by ei, cleared by the next instruction
    end
  end
end

assign o_epc      = epc_r;
assign o_irq_take = i_irq & ie_r & ~ei_shadow_r;   // Phase 2 (i_irq = 0 in Phase 1)
```

---

## 10. Phase 2: MMIO and Interrupts

### 10.1 Memory-Mapped I/O & Peripheral Bus
- Address decoding in `soc.v`: `0x0000_0000`–`0x0000_07FF` DMEM (2 KB); `0xFFFF_0000` and above I/O (exact map TBD, see §13).
- Peripherals are accessed with ordinary `lw`/`sw` (no dedicated I/O instructions).
- XSoC-style bus: one-hot `sel[i]`, shared `addr`/`wdata`/`we`/`re`, read data through an explicit multiplexer (no internal tri-states).
- Candidate peripherals: Timer/Counter, GPIO (debouncing, edge detection), PWM, UART.

### 10.2 Interrupts (single-vector, non-nested)
- **Detection:** interrupt controller in `soc.v` (pending/mask registers, MMIO) drives one `i_irq` to the CPU.
- **Take condition:** `irq_take = i_irq && ie_r && !ei_shadow_r`, sampled at each instruction boundary.
- **Entry (hardware, no instruction), "cancel the current instruction":**
  - suppress RegWrite/MemWrite (and IE writes) of the instruction at PC;
  - `EPC ← PC`;
  - `IE ← 0`;
  - `PC ← vector` (`PCSrc = 100`).
  - The cancelled instruction is re-executed after the return. Branches and jumps need no special handling.
- **Return (mandatory sequence, the last three instructions of the handler):**

  ```
  mfc0 $k0, $14     # $k0 = EPC
  ei                # IE = 1; interrupt shadow on the next instruction
  jr   $k0          # cannot be interrupted; resumes at the cancelled instruction
  ```

  - `ei` must **immediately** precede `jr $k0`, and `$k0` must not change between `mfc0` and `jr`.
  - Why the shadow is required: without it, an interrupt could be taken at the `jr`. The new entry would save the address of the `jr` in EPC, the handler would overwrite `$k0` with that address, and the final `jr $k0` would jump to itself forever.
  - The first instruction at the return address can already be interrupted.
- **Critical sections in main code:** `di` … `ei`. The shadow after `ei` there is harmless (one instruction later than otherwise).
- **Handler rules:** IE is 0 inside the handler; the handler never uses `di`, and uses `ei` only in the return sequence. `$k0`/`$k1` are free to use; other registers are saved to fixed DMEM addresses relative to `$zero` (e.g. `sw $t0, 0x7F0($zero)`). Main code never uses `$k0`/`$k1`.

---

## 11. Python Toolchain

All tools live in `tools/` and share one ISA definition.

### 11.1 Structure
- `isa.py`: single source of truth for mnemonics, formats (**R, I, J, COP0**), opcode/funct/fixed fields (including `rt = 00001` for `bgez`, `rt = 00000` for `bgtz`, `rd = 14` for `mfc0`), operand syntax, immediate signedness, register names.
- `assembler.py`: `.asm` → `program.mem` (+ `data.mem`, listing, symbol table).
- `refsim.py`: golden model; models GPRs, PC, DMEM (little-endian), **EPC, IE, `ei_shadow_r`**.
- `run_tests.py`: assemble → XSim batch → refsim → compare.
- `tests/`: one `.asm` per test.

### 11.2 Assembler
- Two-pass; `#` comments, labels, decimal/hex/negative immediates, ABI and numeric register names.
- Directives: `.text`, `.data`, `.word`.
- Branch offset `(target - (PC + 4)) >> 2` (signed 16) for `beq`, `bne`, `bgez`, `bgtz`; jump index `target[27:2]`.
- Operand syntax: `bgez rs, label`; `bgtz rs, label`; `lb rt, imm(rs)`; `mfc0 rt, $14`; `di` and `ei` take **no operands**.
- Range checks: signed 16 for `addi`/`lw`/`lb`/`sw`/branches; unsigned 16 for `xori`/`lui`; 0–31 for `shamt`.
- **COP0:** `di`, `ei` emit `0x41606000`, `0x41606020`. Errors: `mfc0` with any CP0 register other than `$14`; `di rt`/`ei rt` with non-zero `rt`.
- Pseudo-instructions (expanded only into our ISA, `$at` as scratch):
  - `nop` → `sll $0, $0, 0`
  - `move rd, rs` → `add rd, rs, $zero`
  - `not rd, rs` → `nor rd, rs, $zero`
  - `li rt, imm` → `addi rt, $zero, imm` (fits signed 16) / `xori rt, $zero, imm` (fits unsigned 16) / `lui rt, hi` + `xori rt, rt, lo` (omit `xori` when `lo = 0`)
  - `la rt, label` → `lui rt, hi` + `xori rt, rt, lo`
  - `b label` → `beq $zero, $zero, label`
  - `blt`/`bgt`/`ble`/`bge` → `slt $at, …` + `bne`/`beq $at, $zero, label`
  - Never emit instructions outside the ISA (e.g., `ori`, `andi`, `addiu`, `sb`, `eret`).
- Errors with file and line; never emit a partial `.mem`.
- Output: `program.mem`, one 8-hex-digit word per line.

### 11.3 Reference Simulator
- Exact §4 semantics: no delay slots, no overflow exceptions, `$zero` hardwired, 32-bit wraparound, little-endian `lb`.
- `mfc0 rt, $14`: `rt ← EPC`. `di`: `IE ← 0`. `ei`: `IE ← 1`, shadow set for the next instruction. EPC = 0, IE = 0, shadow = 0 at reset.
- Phase 2: models interrupt entry with the same "cancel the current instruction" rule and the `ei` shadow.
- Outputs final registers, DMEM, EPC, IE and the committed-instruction PC trace.

### 11.4 Test Flow
1. Assemble each `tests/*.asm`.
2. Run `tb_soc.v` in XSim batch (`xvlog` → `xelab` → `xsim -R`).
3. Run `refsim.py` on the same machine code.
4. Compare registers, DMEM, **EPC, IE** and (optionally) PC trace; report the first mismatch.

**MARS cross-check:** *Settings → Memory Configuration → Compact, Text at Address 0*. MARS is little-endian, so `lb` results must match. Tests that use `di`/`ei` are excluded (MARS does not implement them). Tests with `mfc0` can run in MARS; EPC there is only set by exceptions, so the expected value is 0.

### 11.5 Test Conventions
- **Halt:** self-loop `end: j end`; the testbench stops when the PC is unchanged for two cycles, or at a cycle limit (timeout = failure). See §13 for the pipeline-compatible alternative.
- **State dump:** `tb_soc.v` writes register file, DMEM, `epc_r` and `ie_r` via hierarchical references.
- **Traces:** `TRACE_PC` prints `cycle, PC, instruction`; `TRACE_REGS` prints register writes.

### 11.6 Phase 1 Test Plan
- One test per instruction, plus combined programs (loops, `jal`/`jr $ra`, stack use).
- Edge cases:
  - writes to `$zero`; negative immediates; forward/backward and taken/not-taken branches;
  - `slt` with `0x8000_0000` vs `1` (signed);
  - shifts by 0 and 31;
  - `lui` + `xori` for `0xFFFF_0000`, `0x1234_5678` and `0x8000_8000` (low half ≥ `0x8000` must not corrupt the high half); `li` with a value that fits only unsigned 16 (`0x0000_FFFF`);
  - `xori` with `0xFFFF` (must zero-extend); `nor` as NOT;
  - `lw`/`sw` at the first and last DMEM words.
- **`lb` tests:** all four byte offsets of one word (checks little-endian order); bytes `0x7F` and `0x80` (sign extension); first and last DMEM bytes (`0x000`, `0x7FF`).
- **`bgez`/`bgtz` tests:** `rs = 0`, `1`, `-1`, `0x7FFF_FFFF`, `0x8000_0000`, taken and not taken, forward and backward. `bgtz` with `rs = 0` must not be taken. `bgez` with `$at` loaded with different values (proves the B-port value is ignored). Single-bit test with `sll` + `bgez`.
- **COP0 tests:**
  - `ei`, `di`, `ei`, `di` sequences: check `ie_r` after each.
  - `mfc0 $t0, $14` after reset: `$t0 = 0`.
  - Return sequence without interrupts: EPC = 0 after reset, so `mfc0 $k0, $14` → `ei` → `jr $k0` restarts at address 0 with IE = 1. Test: at address 0, check a DMEM flag; on the first pass set the flag and execute the return sequence; on the second pass jump to `end`. Expected: flag set, IE = 1, `$k0 = 0`, end reached.
  - Encodings checked against `mfc0 $k0, $14` = `0x401A7000`, `di` = `0x41606000`, `ei` = `0x41606020`.
- **Phase 2 tests (planned):** IRQ asserted while `ei` executes (not taken at the next instruction, taken at the one after); interrupt taken at a branch, jump, `lw` and `sw` (cancelled and re-executed); `di` takes effect immediately.

---

## 12. Pipeline Readiness (future)

Rules so a future 5-stage pipeline runs the same software and the same tests:
- No branch or load delay slots, ever (§2.1). The same `refsim.py` validates both CPUs.
- One destination register per instruction; no multi-cycle units.
- `beq`/`bne` compare two registers and `bgez`/`bgtz` compare one register against zero, so all branches can resolve in ID; `blt`/`bge` stay pseudo-instructions.
- Every instruction carries its PC down the pipeline (needed for EPC).
- `di`/`ei` write IE in the **same stage** where interrupts are sampled, so `di` takes effect immediately with no `ehb`.
- The instruction immediately after `ei` in program order is never interrupted (shadow).
- EPC is written only at interrupt entry, which flushes the pipeline, so `mfc0` has no hazard on EPC. `jr $k0` after `mfc0 $k0` is a normal RAW dependency (forwarding/hazard unit).
- `lb` selects the byte in the MEM stage; it has the same load-use hazard as `lw`.
- Control word grouped by stage: EX (`ALUCtrl`, `ALUSrc`, `ExtOp`), MEM (`MemRead`, `MemWrite`, `LoadByte`), WB (`RegWrite`, `RegDst`, `WBSrc`), plus `PCSrc`, `IEWrite`, `IEVal`.
- `next_pc.v`, `load_ext.v` and `cop0.v` are separate modules; future hazard and forwarding units connect through named ports.

---

## 13. Open Items (recommended, not yet adopted)

- **I/O map in `0xFFFF_8000`–`0xFFFF_FFFF`:** every peripheral reachable as `lw/sw off($zero)` with a negative offset, in one instruction.
- **Peripheral registers with SET / CLEAR / TOGGLE and write-1-to-clear flags;** important bits in the lower 16 bits. More valuable now that `andi`/`ori` are unavailable: setting or clearing a peripheral bit becomes a single `sw`.
- **Pipeline-compatible halt:** end tests with a write to a "test done" MMIO address instead of the PC self-loop; trace committed instructions only.
- **Assembler directives `.byte` / `.ascii`:** convenient byte data for `lb` tests and strings (`.word` with little-endian packing works meanwhile).
- **Pseudo-instructions `bltz` / `blez`:** e.g. `slt $at, rs, $zero` + `bne $at, $zero, label`.
- Instructions considered and **not** added: `lbu`, `jalr`, `slti`/`sltiu`, `sllv`/`srlv`, `sra`, `sltu` (dropped in revision 3), `bltz`/`blez` (redundant with `bgez`/`bgtz` plus inversion), `mtc0`, `mult` (would lengthen the critical path), `swio` (not MIPS32; MMIO covers I/O).
- Not available (assigned to other groups): `eret`, `ori`, `andi`, `addiu`, `sb`.

---

## 14. Guidelines for the Assistant

- Clean, synthesizable Verilog-2001 for Vivado: defaults at the top of every `always @(*)`, `default:` in every `case`, `=`/`<=` never mixed.
- Respect the naming conventions and the 25-mnemonic ISA with the encodings in §4; unused bits always `0`; little-endian byte order.
- Never use instructions outside the ISA, in particular `ori`, `andi`, `addiu`, `sb`, `eret`, `sltu`.
- Strict CU/Datapath separation; every new signal is a named port.
- Python 3; `isa.py` is the single source of truth. Any ISA change updates `isa.py`, `control_unit.v`, `refsim.py` and tests together.
- Phase 2 features pluggable in `soc.v` without changing `cpu.v` logic.
- Prefer designs that reuse the existing datapath and keep the CU/Datapath interface clean.
- Respect the Zybo Z7-10 constraints and the pipeline-readiness rules (§12).
