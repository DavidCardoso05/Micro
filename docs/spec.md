# Project Spec: MIPS32 SoC on FPGA & Toolchain

**Revision 4** (2026-11-16). Replaces revision 3 (`project_spec_rev3.md`, removed; see git history).

**Changes from revision 3:**
- **No pipeline, no delay slots.** Every instruction completes in one cycle, except **`lw` and `lb`, which take two**. `sw` takes one. The pipeline-readiness rules are removed.
- **Memories:** IMEM is 512 words with an **asynchronous** read (LUTs), addressed by the PC. DMEM is 512 words with **synchronous read and write** (inferred block RAM). Both are inferred from plain Verilog (no XPM macros).
- **Memory control signals:** `MemEnable` and `MemRW` (1 = read, 0 = write) replace `MemRead` and `MemWrite`.
- **Load wait:** a flip-flop `MemPhase` in the datapath and a new control signal `PCWrite` (the enable of the PC register) stretch `lw`/`lb` over two cycles (§6.3). DMEM is accessed only in the first cycle.
- **The step/enable input `i_en` is removed** from every module.
- **Interrupts:** `irq_take = irq & IE & ~ei_shadow & ~MemPhase`. Interrupt entry is implemented in the CPU now; Phase 2 only adds the interrupt source. Vector = `0x0000_0004`, reset = `0x0000_0000`.
- **Program layout fixed:** word 0 is `j main`, word 1 is `j handler` (§10.3).
- **Reset:** synchronous, active high, in every module with state, including the register file.
- **Verification:** module testbenches are stimulus-only and are read in the waveform viewer (§2.2).

---

## 1. Overview and Project Structure

We are developing from scratch a 32-bit MIPS System-on-Chip (SoC) in Verilog, based on a Harvard architecture without a pipeline, together with a Python toolchain.

**Course context:** *Projecto de Sistemas Dedicados*, Prof. Adriano Tavares (DEI, Universidade do Minho). The lecture material uses didactic processors (EC-1/EC-2, 32-bit VeSPA, 16-bit GR0040/XSoC) rather than MIPS, but the engineering methodology, RTL coding style and architectural trade-offs defined there apply to our MIPS implementation.

**Purpose:** the processor is a learning project. **Always prefer the simplest and most readable solution**, not the most complete one.

**Final goal:** a bare-metal, interrupt-driven microcontroller-style SoC that controls peripherals through memory-mapped I/O.

Phases:

- **Phase 1 (current):** the CPU core (`cpu.v`) with the **17-instruction class-wide ISA** plus the **8 group-selected extensions (25 mnemonics, 24 encodings)**, the two memories, and module testbenches. Interrupt entry and return are already implemented in the CPU; in Phase 1 `i_irq` is tied to `0`.
  **Status:** CPU RTL and module testbenches done; `soc.v` not started; toolchain: only `tools/isa.py` exists.
- **Phase 2:** `soc.v` with the address decoder, Memory-Mapped I/O (e.g. GPIO, Timer), and the interrupt source that drives `i_irq` (single vector, non-nested).

---

## 2. Design Methodology

Top-down hierarchical refinement. Each level is a formal contract that higher levels rely on and lower levels must satisfy.

### 2.1 Architectural Level (ISA)

The ISA (§4) and the MIPS32 ABI (§5) are a **strict formal contract** between software (assembler, test programs) and hardware (CPU).

- Encodings follow **MIPS32 Release 2–5** exactly, for compatibility with standard tools. (Release 6 is **not** used: it removed `addi` and re-encoded other instructions.) No custom (non-MIPS) instructions.
- **Unused instruction bits are always `0`** (e.g., `shamt = 00000` on non-shift R-type, `rs = 00000` on `sll`/`srl`/`lui`, `rt = rd = shamt = 0` on `jr`, `rt = 00000` on `bgtz`/`di`/`ei`, `instr[10:0] = 0` on `mfc0`). On `bgez`, `rt = 00001` is a fixed sub-opcode, not an operand.
- **Byte order: little-endian** (as in MARS). The byte at address `A` is bits `[8·A[1:0]+7 : 8·A[1:0]]` of word `A >> 2`.
- `add`, `sub`, `addi` do **not** raise overflow exceptions (they behave like `addu`/`subu`/`addiu`).
- **No branch/jump delay slots and no load delay slot.** The two-cycle `lw`/`lb` is invisible to software: the next instruction always sees the loaded value.
- The opcode/funct table is defined **once** in `tools/isa.py` (§11) and must match `control_unit.v`.

### 2.2 Verification

- **Module testbenches** (`sim/tb_*.v`) contain **stimuli only**: no checks, no reference models, no error counters, no random tests and no PASS/FAIL messages. The result is read in the waveform viewer.
  - Inputs are driven, the testbench waits (`#10`) and moves to the next case; it ends with `$finish`.
  - One short comment per case says what the waveform should show.
  - Clocked modules: `always #5 clk = ~clk`; inputs change on the falling edge; the testbench starts with a reset that catches a rising edge.
  - Few, chosen cases: one per instruction or operation, plus the edge cases worth showing. Each testbench fits in one or two screens.
  - `sim/tb_alu.v` and `sim/tb_register_file.v` are the style reference.
- **Program-level tests** (planned, Phase 1 toolchain work, §11.4): assembled programs run on the whole CPU and are compared against the Python reference simulator.

### 2.3 RTL / Structural Level

`cpu.v` is **strictly split** into:

- **Control Unit:** purely combinational.
- **Datapath:** PC, register file, ALU, extenders, load-extension unit, multiplexers, `MemPhase`, COP0 (EPC, IE, `ei_shadow`).

They communicate **only** through explicit, named ports:

- **Control Word** (CU → Datapath): `RegWrite`, `RegDst[1:0]`, `ALUSrc`, `ALUCtrl[3:0]`, `ExtOp`, `LoadByte`, `WBSrc[1:0]`, `PCSrc[2:0]`, `PCWrite`, `IEWrite`, `IEVal`.
- **Memory control** (CU → outside the CPU): `MemEnable`, `MemRW`.
- **Status Signals** (Datapath → CU): `zero`, `rs_neg` (`rs[31]`), `irq_take`, `mem_phase`.

---

## 3. Hardware Platform and Tools

- **FPGA board:** Digilent Zybo Z7-10 (`xc7z010clg400-1`): 17,600 LUTs | 35,200 flip-flops | 270 KB Block RAM. Board I/O: push-buttons, slide switches, LEDs. Only the Programmable Logic is used.
- **Clocking (Phase 2, `soc.v`):** 125 MHz oscillator (pin `K17`, 8 ns constraint). A **Clocking Wizard (MMCM)** generates the **50 MHz** CPU clock. Clocks are never divided with logic.
- **Hardware IDE:** Xilinx Vivado 2024.2, synthesizable Verilog-2001 (no SystemVerilog), XSim behavioural simulation.
- **Memories:** inferred from plain Verilog:
  - **IMEM:** 512 × 32 bits, asynchronous read → distributed ROM (LUTs). Initialised with `$readmemh` from `program.mem`.
  - **DMEM:** 512 × 32 bits (2 KB), synchronous read and write → one block RAM (RAMB18). Word-wide with a single write enable: the ISA has no byte stores.
- **Register file:** 32 × 32 bits in flip-flops, asynchronous reads, synchronous reset. Never block RAM.
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
| 11 | `lw rt, imm(rs)` | `6'h23` | `rt = MEM32[rs + SignExt(imm)]` (word-aligned; **2 cycles**) |
| 12 | `sw rt, imm(rs)` | `6'h2B` | `MEM32[rs + SignExt(imm)] = rt` (word-aligned; 1 cycle) |
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
| 20 | `lb rt, imm(rs)` | opcode `6'h20` | `rt = SignExt(MEM8[rs + SignExt(imm)])` (any byte address; **2 cycles**) |
| 21 | `bgez rs, label` | opcode `6'h01` (REGIMM), `rt = 00001` | `if ($signed(rs) >= 0) PC = (PC + 4) + (SignExt(imm) << 2)` |
| 22 | `bgtz rs, label` | opcode `6'h07`, `rt = 00000` | `if ($signed(rs) > 0) PC = (PC + 4) + (SignExt(imm) << 2)` |

**COP0** (`opcode = 6'h10`; R-type-like layout, decoded by opcode, **not** inside the R-type case)

| # | Instr | Fields | Encoding | Semantics |
|---|---|---|---|---|
| 23 | `mfc0 rt, $14` | `010000 \| 00000 \| rt \| 01110 \| 00000000 \| sel=000` | e.g. `mfc0 $k0, $14` = `0x401A7000` | `rt = EPC` |
| 24 | `di` | `010000 \| 01011 \| rt=00000 \| 01100 \| 00000 \| sc=0 \| 00 \| 000` | `0x41606000` | `IE = 0` |
| 25 | `ei` | `010000 \| 01011 \| rt=00000 \| 01100 \| 00000 \| sc=1 \| 00 \| 000` | `0x41606020` | `IE = 1`; interrupt shadow on the next instruction |

Notes on COP0 instructions:
- `mfc0` is supported **only for EPC** (CP0 register 14, select 0). Other CP0 registers do not exist in our CPU; the assembler rejects them and the hardware decodes them as `nop`. There is no `mtc0`, no Cause register and no `eret`: software can read EPC but never write it.
- `di`/`ei` are one encoding (MFMC0) that differs only in bit 5 (`sc`); hardware: `IE ← instr[5]`.
- Real MIPS32 `di rt`/`ei rt` also copy Status into `rt`. **We only support `rt = $zero`** (the argument-less form), so that write is discarded and behaviour is identical to MIPS32. The assembler rejects `di rt`/`ei rt` with a non-zero `rt`.
- `di` takes effect **immediately**: no interrupt is taken after `di` executes.
- **`ei` interrupt shadow:** interrupts are **not taken on the instruction immediately after `ei`**. This makes the return sequence `ei` → `jr $k0` atomic (§10.2). MIPS32 does not guarantee that `ei` takes effect until an `ehb` executes, so a deterministic one-instruction delay is a valid implementation of the architecture, not a change to it.
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

- Register 0 reads `32'b0` (forced on the read ports); writes to it are ignored.
- **2 asynchronous read ports** (`rs`, `rt`); **1 synchronous write port**. `i_we` (= `RegWrite`) is the only enable; the module has no other ports and must not get any.
- Synchronous reset (`i_rst`) clears all registers to 0.
- **RegDst mux (3 inputs):** `00` rt, `01` rd, `10` `5'd31`.
- **Write-back mux (4 inputs, `WBSrc[1:0]`):** `00` ALU result, `01` DMEM data after `load_ext`, `10` `PC + 4`, `11` EPC (`mfc0`).

### 5.1 Special CPU State (COP0 subset, `cop0.v`)

| Register | Width | Reset | Written by | Read by |
|---|---|---|---|---|
| `epc_r` | 32 | `32'h0` | interrupt entry: `EPC ← PC` | `mfc0 rt, $14` |
| `ie_r` | 1 | `1'b0` | `ei` (1), `di` (0), interrupt entry (0) | `irq_take` |
| `ei_shadow_r` | 1 | `1'b0` | set by `ei`, cleared by the next instruction | `irq_take` |

- `irq_take = i_irq & ie_r & ~ei_shadow_r & ~i_mem_phase` (combinational output of `cop0.v`).
- Software reads EPC with `mfc0`; it cannot write EPC (no `mtc0`) and cannot read IE (no Status register).
- Boot sequence: IE starts at 0; software enables interrupts with `ei` when ready.

---

## 6. Control Unit

Purely combinational. It decodes `opcode`, `funct`, `rt` (REGIMM, `bgtz`), and for COP0 the `rs`/`rd`/`sel` fields and bit 5. All outputs default to safe values (no writes, no memory access, `PCSrc = PC+4`, `IEWrite = 0`); every `case` has a `default:`. Unknown encodings behave as `nop`.

The CU has four parts: (1) instruction decode, which looks only at the instruction fields; (2) branch condition (§6.1); (3) next-PC select (§6.2); (4) load wait and interrupt cancellation (§6.3, §6.4).

Decoded control word (before §6.3 / §6.4 are applied):

| Instruction | RegWrite | RegDst | ALUSrc | ExtOp | MemEnable | MemRW | LoadByte | WBSrc | PCSrc | IEWrite | IEVal |
|---|---|---|---|---|---|---|---|---|---|---|---|
| add, sub, and, or, xor, nor, slt | 1 | rd | reg | – | 0 | – | – | ALU | PC+4 | 0 | – |
| sll, srl | 1 | rd | reg | – | 0 | – | – | ALU | PC+4 | 0 | – |
| addi | 1 | rt | imm | sign | 0 | – | – | ALU | PC+4 | 0 | – |
| xori, lui | 1 | rt | imm | zero | 0 | – | – | ALU | PC+4 | 0 | – |
| lw | 1 | rt | imm | sign | 1 | 1 (read) | 0 | Mem | PC+4 | 0 | – |
| lb | 1 | rt | imm | sign | 1 | 1 (read) | 1 | Mem | PC+4 | 0 | – |
| sw | 0 | – | imm | sign | 1 | 0 (write) | – | – | PC+4 | 0 | – |
| beq, bne | 0 | – | reg | – | 0 | – | – | – | branch | 0 | – |
| bgez, bgtz | 0 | – | reg | – | 0 | – | – | – | branch | 0 | – |
| j | 0 | – | – | – | 0 | – | – | – | jump | 0 | – |
| jal | 1 | $31 | – | – | 0 | – | – | PC+4 | jump | 0 | – |
| jr | 0 | – | – | – | 0 | – | – | – | rs | 0 | – |
| mfc0 | 1 | rt | – | – | 0 | – | – | EPC | PC+4 | 0 | – |
| di | 0 | – | – | – | 0 | – | – | – | PC+4 | 1 | 0 |
| ei | 0 | – | – | – | 0 | – | – | – | PC+4 | 1 | 1 |

- "–" = don't care, but the RTL still drives a defined default (`MemRW` defaults to 1).
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

- `beq`, `bne`, `bgtz` use ALU SUB with `ALUSrc = reg`. For `bgtz`, `rt = 00000`, so the B port reads `$zero`, the ALU computes `rs - 0`, and `zero = (rs == 0)`.
- `bgez` uses **only** `rs_neg`. Its `rt` field is `00001`, so the B port reads `$at` and `zero` is meaningless for it.
- `rs_neg` is `rs[31]` taken directly from register-file read port A (not from the ALU).

### 6.2 Next-PC Logic (PCSrc, 3 bits, `next_pc.v`)

| PCSrc | Next PC | Used by |
|---|---|---|
| `000` | PC + 4 | sequential execution |
| `001` | (PC+4) + (SignExt(imm) << 2) | beq, bne, bgez, bgtz (if taken) |
| `010` | {(PC+4)[31:28], index, 00} | j, jal |
| `011` | rs | jr |
| `100` | `0x0000_0004` (interrupt vector) | interrupt entry |
| `101`–`111` | PC + 4 | reserved |

- `PCSrc` chooses the address; **`PCWrite` authorises the write** of the PC register (§6.3).
- The PC resets to `0x0000_0000`. The next PC is an internal wire of the datapath; the CPU does not export it.

### 6.3 Load Wait (`MemPhase`, `PCWrite`)

DMEM reads synchronously, so the loaded word is only available one clock edge after the address. `lw` and `lb` therefore take two cycles. A flip-flop `MemPhase` in the datapath tells the CU which cycle it is in:

```verilog
// Control Unit (combinational)
MemWait   = MemEnable & MemRW & ~MemPhase & ~irq_take;
PCWrite   = ~MemWait;
RegWrite  = dec_RegWrite  & ~irq_take & ~MemWait;
MemEnable = dec_MemEnable & ~irq_take & ~MemPhase;

// Datapath (sequential, synchronous reset to 0)
MemPhase <= ~PCWrite;
```

| | Cycle 1 | Cycle 2 |
|---|---|---|
| `MemPhase` | 0 | 1 |
| `MemWait` / `PCWrite` | 1 / 0 (PC held) | 0 / 1 (PC advances) |
| `RegWrite` | 0 | 1 (writes the loaded value) |
| `MemEnable` | 1: DMEM reads the address at the edge | 0: DMEM idle, its output holds the value |
| Interrupt can be taken | yes (the load is cancelled, nothing happened) | no (`irq_take` is 0 when `MemPhase = 1`) |

- The address (`rs + imm`) is the same in both cycles, because the PC and the register file do not change in between.
- **DMEM is accessed once per load.** This matters for MMIO reads with side effects (§10.1).
- `sw` never waits (`MemRW = 0`), so `MemPhase` is never 1 during a `sw`.
- After cycle 2, `PCWrite = 1`, so `MemPhase` returns to 0 for the next instruction.

### 6.4 Interrupt Cancellation

When `irq_take = 1`, the instruction at PC is cancelled:
- `PCSrc = 100` (vector) and `PCWrite = 1` (follows from `MemWait = 0`);
- `RegWrite = 0`, `MemEnable = 0`, `IEWrite = 0`;
- in the same edge `cop0.v` writes `EPC ← PC`, `IE ← 0`, `ei_shadow ← 0`.

The cancelled instruction is re-executed after the return. Branches, jumps and loads need no special handling.

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
| `1001` | — | reserved (formerly SLTU) → `0` | — |
| `1010` | LUI | `B[15:0] << 16` | lui |
| `1011`–`1111` | — | reserved → `0` | — |

- `zero = (y == 32'b0)`; `beq`/`bne`/`bgtz` reuse SUB and `zero`.
- Inputs: `i_a` (rs), `i_b` (rt or extended immediate), `i_shamt` (`instr[10:6]`), `i_ctrl[3:0]`. Outputs: `o_y[31:0]`, `o_zero`.

---

## 8. Verilog-2001 Coding Style & FPGA Synthesis Rules

### 8.1 Blocking vs. Non-Blocking
- `=` only in combinational blocks (`always @(*)`); `<=` only in sequential blocks (`always @(posedge i_clk)`); never mixed; one `always` block per signal.

### 8.2 Zero Unintended Latches
Every `always @(*)`: defaults for all outputs at the top, `default:` in every `case`, no undriven paths.

### 8.3 Resources, Timing and Reset
- ADD, SUB and SLT share one adder (SUB as `A + ~B + 1`).
- Critical paths:
  - every instruction: PC → IMEM (async) → register read → ALU → next PC / write-back mux;
  - load, cycle 1: … → ALU → DMEM address (registered by the block RAM);
  - load, cycle 2: DMEM output register → `load_ext` → write-back mux → register file.
  Check WNS ≥ 0 at 50 MHz once `soc.v` exists; if it fails, lower the MMCM frequency.
- **Reset:** synchronous, active-high `i_rst`, in every module with state: the `always` block has only `posedge i_clk`. PC ← `0`, register file ← `0`, `MemPhase` ← `0`, EPC ← `0`, IE ← `0`, `ei_shadow` ← `0`. Memory arrays are not reset (block RAM contents cannot be).
- **No step/enable input.** State changes on every clock edge; only `PCWrite` (PC) and the write enables qualify it.

### 8.4 Naming Conventions
`i_` inputs, `o_` outputs, `_r` registers, `u_` instances, `UPPER_CASE` parameters and macros. Module and signal names in English.

---

## 9. Hardware Architecture & Verilog Hierarchy

```
soc.v (Phase 2, not yet written)
├── u_imem : instruction_memory.v   512 words, async read, addr = PC[10:2]
├── u_dmem : data_memory.v          512 words, sync read/write, addr = addr[10:2]
└── u_cpu  : cpu.v
    ├── u_control_unit : control_unit.v
    └── u_datapath     : datapath.v
        ├── u_pc_reg        : pc_reg.v         (enable = PCWrite)
        ├── u_next_pc       : next_pc.v
        ├── u_mux_regdst    : mux3 (muxes.v)
        ├── u_register_file : register_file.v
        ├── u_sign_extend   : sign_extend.v
        ├── u_mux_alusrc    : mux2_32bit (muxes.v)
        ├── u_alu           : alu.v
        ├── u_load_ext      : load_ext.v
        ├── u_cop0          : cop0.v
        ├── u_mux_wb        : mux4 (muxes.v)
        └── mem_phase_r     (flip-flop, in datapath.v)
```

1. **`soc.v` (Phase 2):** board ports, Clocking Wizard, reset synchronizer, address decoder, MMIO peripherals and interrupt source. Instantiates the memories and the CPU, and makes the DMEM write enable: `we = dmem_enable & ~dmem_rw`.
2. **`instruction_memory.v`:** ports `i_addr`, `o_instr`. Parameters `ADDR_BITS = 9`, `INIT_FILE = "program.mem"`. Index `i_addr[ADDR_BITS+1:2]`; the low two bits are ignored.
3. **`data_memory.v`:** ports `i_clk`, `i_en`, `i_we`, `i_addr`, `i_wd`, `o_rd`. Parameter `ADDR_BITS = 9`. With `i_en = 1`, at the rising edge: `o_rd ← mem[index]` (read-first: the old value on a write) and, if `i_we = 1`, `mem[index] ← i_wd`. With `i_en = 0`, `o_rd` holds. No reset.
4. **`cpu.v`:** `control_unit` + `datapath`, connected only through the control word and status signals. Ports:

   | Port | Dir | Width | Meaning |
   |---|---|---|---|
   | `i_clk`, `i_rst` | in | 1 | clock; synchronous active-high reset |
   | `i_irq` | in | 1 | interrupt request (0 in Phase 1) |
   | `o_pc` | out | 32 | IMEM address |
   | `i_instr` | in | 32 | instruction at `o_pc` |
   | `o_dmem_enable` | out | 1 | `MemEnable` |
   | `o_dmem_rw` | out | 1 | `MemRW`: 1 read, 0 write |
   | `o_dmem_addr` | out | 32 | ALU result (byte address) |
   | `o_dmem_wd` | out | 32 | rt (data for `sw`) |
   | `i_dmem_rd` | in | 32 | data read (registered; used in the second load cycle) |

5. **`control_unit.v`:** §6. Inputs: instruction fields, `i_zero`, `i_rs_neg`, `i_irq_take`, `i_mem_phase`. Outputs: the control word including `o_mem_enable`, `o_mem_rw`, `o_pc_write`.
6. **`datapath.v`:** no decoding. Contains `mem_phase_r` (§6.3) and the submodules in the tree above.
7. **`load_ext.v`:** `lw` passes the word; `lb` selects the byte with `addr[1:0]` (little-endian: `00` → `[7:0]` … `11` → `[31:24]`) and sign-extends it.

---

## 10. Phase 2: MMIO and Interrupts

### 10.1 Memory-Mapped I/O
- Address decoding in `soc.v`: `0x0000_0000`–`0x0000_07FF` DMEM (2 KB); `0xFFFF_0000` and above I/O (exact map TBD, §12).
- Peripherals are accessed with ordinary `lw`/`sw` (no dedicated I/O instructions).
- **Peripheral reads follow the DMEM timing:** the read is registered on the edge where `MemEnable = 1` and the output holds while `MemEnable = 0`. The CPU accesses the address only once per load (§6.3), so a read with side effects (e.g. popping a UART FIFO) happens exactly once.
- Read data reaches the CPU through an explicit multiplexer (no internal tri-states).
- Candidate peripherals: GPIO, Timer.

### 10.2 Interrupts (single vector, non-nested)
- **Source:** logic in `soc.v` drives one `i_irq` to the CPU.
- **Take condition:** `irq_take = i_irq & IE & ~ei_shadow & ~MemPhase`.
- **Entry (hardware, no instruction):** cancel the instruction at PC (§6.4), `EPC ← PC`, `IE ← 0`, `PC ← 0x0000_0004`.
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

### 10.3 Program Layout

Reset (`0x0`) and the vector (`0x4`) are consecutive words, so every program starts with two jumps:

```
0x00:  j main       # reset
0x04:  j handler    # interrupt vector
main:  ...
```

- `j handler` lets the handler live anywhere.
- A program that never executes `ei` may put any instruction at `0x04`; the layout is still recommended.

---

## 11. Python Toolchain

All tools live in `tools/` and share one ISA definition. **Only `isa.py` exists today**; the rest is planned.

### 11.1 Structure
- `isa.py`: single source of truth for mnemonics, formats (**R, I, J, COP0**), opcode/funct/fixed fields (including `rt = 00001` for `bgez`, `rt = 00000` for `bgtz`, `rd = 14` for `mfc0`), operand syntax, immediate ranges, register names.
- `assembler.py` (planned): `.asm` → `program.mem` (+ `data.mem`, listing, symbol table).
- `refsim.py` (planned): golden model; models GPRs, PC, DMEM (little-endian), **EPC, IE, `ei_shadow`**. It works at instruction level: the two-cycle loads are not modelled.
- `run_tests.py` (planned): assemble → XSim batch → refsim → compare.
- `tests/`: one `.asm` per test.

### 11.2 Assembler
- Two-pass; `#` comments, labels, decimal/hex/negative immediates, ABI and numeric register names.
- Directives: `.text`, `.data`, `.word`.
- Branch offset `(target - (PC + 4)) >> 2` (signed 16) for `beq`, `bne`, `bgez`, `bgtz`; jump index `target[27:2]`.
- Operand syntax: `bgez rs, label`; `bgtz rs, label`; `lb rt, imm(rs)`; `mfc0 rt, $14`; `di` and `ei` take **no operands**.
- Range checks: signed 16 for `addi`/`lw`/`lb`/`sw`/branches; unsigned 16 for `xori`/`lui`; 0–31 for `shamt`.
- **COP0:** `di`, `ei` emit `0x41606000`, `0x41606020`. Errors: `mfc0` with any CP0 register other than `$14`; `di rt`/`ei rt` with non-zero `rt`.
- **Program layout check (§10.3):** if the program uses `ei`, words `0x00` and `0x04` must be `j` instructions.
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
- Output: `program.mem`, one 8-hex-digit word per line. `.mem` files are never committed.

### 11.3 Reference Simulator
- Exact §4 semantics: no delay slots, no overflow exceptions, `$zero` hardwired, 32-bit wraparound, little-endian `lb`.
- `mfc0 rt, $14`: `rt ← EPC`. `di`: `IE ← 0`. `ei`: `IE ← 1`, shadow set for the next instruction. EPC = 0, IE = 0, shadow = 0 at reset.
- Interrupt entry with the same "cancel the current instruction" rule and the `ei` shadow.
- Outputs final registers, DMEM, EPC, IE and the trace of completed instructions.

### 11.4 Program-Level Test Flow (planned)
1. Assemble each `tests/*.asm`.
2. Run `tb_soc.v` (or a CPU + memories testbench) in XSim batch (`xvlog` → `xelab` → `xsim -R`).
3. Run `refsim.py` on the same machine code.
4. Compare registers, DMEM, EPC, IE and (optionally) the PC trace; report the first mismatch.

**MARS cross-check:** *Settings → Memory Configuration → Compact, Text at Address 0*. MARS is little-endian, so `lb` results must match. Tests that use `di`/`ei` are excluded (MARS does not implement them). Tests with `mfc0` can run in MARS; EPC there is only set by exceptions, so the expected value is 0.

### 11.5 Test Conventions
- **Halt:** self-loop `end: j end`. The testbench stops when the PC is unchanged after a rising edge **with `PCWrite = 1`**, or at a cycle limit (timeout = failure). (The PC also stays the same during the first cycle of every load, with `PCWrite = 0`; that is not a halt.)
- **State dump:** the testbench writes register file, DMEM, `epc_r` and `ie_r` via hierarchical references.
- **Traces:** count and print only cycles with `PCWrite = 1` (completed instructions), so the trace matches `refsim.py`.

### 11.6 Test Plan (program level)
- One test per instruction, plus combined programs (loops, `jal`/`jr $ra`, stack use).
- Edge cases:
  - writes to `$zero`; negative immediates; forward/backward and taken/not-taken branches;
  - `slt` with `0x8000_0000` vs `1` (signed);
  - shifts by 0 and 31;
  - `lui` + `xori` for `0xFFFF_0000`, `0x1234_5678` and `0x8000_8000`; `li` with `0x0000_FFFF`;
  - `xori` with `0xFFFF` (must zero-extend); `nor` as NOT;
  - `lw`/`sw` at the first and last DMEM words;
  - back-to-back loads (`lw` after `lw`), and a load whose result is used by the next instruction;
  - `lw $t0, 0($t0)` (base register overwritten by the load).
- **`lb` tests:** all four byte offsets of one word (little-endian order); bytes `0x7F` and `0x80` (sign extension); first and last DMEM bytes (`0x000`, `0x7FF`).
- **`bgez`/`bgtz` tests:** `rs = 0`, `1`, `-1`, `0x7FFF_FFFF`, `0x8000_0000`, taken and not taken, forward and backward. `bgtz` with `rs = 0` must not be taken. `bgez` with `$at` loaded with different values. Single-bit test with `sll` + `bgez`.
- **COP0 tests:**
  - `ei`, `di`, `ei`, `di` sequences: check `ie_r` after each.
  - `mfc0 $t0, $14` after reset: `$t0 = 0`.
  - Encodings checked against `mfc0 $k0, $14` = `0x401A7000`, `di` = `0x41606000`, `ei` = `0x41606020`.
- **Interrupt tests (with `i_irq` driven by the testbench):** IRQ while `ei` executes (not taken at the next instruction, taken at the one after); interrupt in the first cycle of `lw` (load cancelled and re-executed), never in the second; interrupt at a branch, jump and `sw`; `di` takes effect immediately; full handler with the return sequence.

---

## 12. Open Items (not yet adopted)

- **I/O map in `0xFFFF_8000`–`0xFFFF_FFFF`:** every peripheral reachable as `lw/sw off($zero)` with a negative offset, in one instruction.
- **Peripheral registers with SET / CLEAR / TOGGLE and write-1-to-clear flags;** important bits in the lower 16 bits (setting or clearing a bit becomes a single `sw`, useful without `andi`/`ori`).
- **MMIO halt alternative:** end tests with a write to a "test done" MMIO address instead of the PC self-loop.
- **Assembler directives `.byte` / `.ascii`:** byte data for `lb` tests and strings (`.word` with little-endian packing works meanwhile).
- **Pseudo-instructions `bltz` / `blez`:** e.g. `slt $at, rs, $zero` + `bne $at, $zero, label`.
- **`scripts/create_project.tcl`** still makes `control_unit` the top when `soc.v` does not exist; `cpu` would be a better default.
- Instructions considered and **not** added: `lbu`, `jalr`, `slti`/`sltiu`, `sllv`/`srlv`, `sra`, `sltu`, `bltz`/`blez`, `mtc0`, `eret`, `mult`, `swio`.
- Not available (assigned to other groups): `eret`, `ori`, `andi`, `addiu`, `sb`.

---

## 13. Guidelines for the Assistant

- Prefer the simplest and most readable solution; this is a learning project.
- Clean, synthesizable Verilog-2001 for Vivado: defaults at the top of every `always @(*)`, `default:` in every `case`, `=`/`<=` never mixed, one block per signal.
- Respect the naming conventions and the 25-mnemonic ISA with the encodings in §4; unused bits always `0`; little-endian byte order.
- Never use instructions outside the ISA, in particular `ori`, `andi`, `addiu`, `sb`, `eret`, `sltu`.
- Strict CU/Datapath separation; every signal between them is a named port.
- `isa.py` is the single source of truth. Any ISA change updates `isa.py`, `control_unit.v`, `refsim.py` and tests together.
- Phase 2 features go in `soc.v` without changing `cpu.v` logic.
- Testbenches follow §2.2 (stimuli only).
- Never commit Vivado-generated files or `.mem` files; add sources under `rtl/` or `sim/` and rebuild with `scripts/create_project.tcl`.
