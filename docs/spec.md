# Project Spec: Single-Cycle MIPS32 SoC on FPGA & Toolchain

**Revision 2** (2026-10-24). Replaces the 22-instruction spec in the project instructions.

**Changes from revision 1:**
- ISA grows to **25 mnemonics / 24 encodings**: adds `eret` (COP0) and `di`/`ei` (COP0, MFMC0, one encoding with an `sc` bit).
- New CPU state: **EPC** (32-bit) and **IE** (1-bit). Interrupt-return mechanism is decided: dedicated `eret`.
- `PCSrc` grows to **3 bits** (5 PC sources + 3 reserved codes).
- Control word gains **`IEWrite` / `IEVal`**; `MemRead` is listed explicitly.
- Interrupt entry rule fixed: **cancel the current instruction**, `EPC ← PC`.
- New §12 with pipeline-readiness rules (a pipelined version is a future goal).
- Open items moved to §13 (recommended, not yet adopted).

---

## 1. Overview and Project Structure

We are developing from scratch a 32-bit MIPS System-on-Chip (SoC) based on a Single-Cycle Harvard architecture in Verilog, together with a Python toolchain: an Assembler, a reference instruction-set simulator (golden model), and an automated test runner driving the Vivado simulator.

**Course context:** *Projecto de Sistemas Dedicados*, Prof. Adriano Tavares (DEI, Universidade do Minho). The lecture material uses didactic processors (EC-1/EC-2, 32-bit VeSPA, 16-bit GR0040/XSoC) rather than MIPS, but the engineering methodology, RTL coding style and architectural trade-offs defined there apply to our MIPS implementation.

**Final goal:** a bare-metal, interrupt-driven microcontroller-style SoC that controls peripherals through memory-mapped I/O.

Phases:

- **Phase 1 (current focus):** Implement the **Class-Wide Base ISA (16 instructions)** plus **9 group-selected extensions (25 mnemonics, 24 encodings)** in Verilog, build the Python toolchain, and validate the processor through automated behavioural simulation in Vivado (XSim). Phase 1 includes the decode and datapath support for `eret`, `di`, `ei` (EPC, IE, PC-source input). Current status: specification and datapath design.
- **Phase 2:** Memory-Mapped I/O (MMIO) map, peripheral bus with custom peripherals (e.g., GPIO, Timer, PWM, UART) and hardware interrupt support (single-vector, non-nested). The interrupt-return mechanism is `eret`. Interrupt **entry** logic (IRQ sampling, writing EPC, jumping to the vector) and the interrupt controller are added in this phase.
- **Future:** pipelined version of the CPU (classic 5-stage). Phase 1/2 decisions must not prevent it (§12).

---

## 2. Design Methodology

Top-down hierarchical refinement. Each level is a formal contract that higher levels rely on and lower levels must satisfy.

### 2.1 Architectural Level (ISA)

The ISA (§4) and the MIPS32 ABI (§5) are a **strict formal contract** between software (assembler, test programs) and hardware (CPU).

- Encodings follow **MIPS32 Release 2–5** exactly, for compatibility with standard tools. (Release 6 is **not** used: it removed `addi` and re-encoded other instructions.)
- **Unused instruction bits are always `0`** (e.g., `shamt = 00000` on non-shift R-type, `rs = 00000` on `sll`/`srl`/`lui`, `rt = rd = shamt = 0` on `jr`, `rt = 00000` on `di`/`ei`).
- `add`, `sub`, `addi` do **not** raise overflow exceptions (they behave like `addu`/`subu`/`addiu`).
- **No branch/jump delay slots and no load delay slot**, now or in any future pipelined version.
- The opcode/funct table is defined **once** in `isa.py` (§11) and must match `control_unit.v`.

### 2.2 Behavioural / Functional Verification

- Test programs assembled by our Python assembler are loaded into IMEM from `.mem` files (`$readmemh` / XPM `MEMORY_INIT_FILE`).
- Trace outputs gated by `` `ifdef TRACE_PC `` and `` `ifdef TRACE_REGS ``.
- Final register state, DMEM snapshot, **EPC/IE**, and PC trace are compared automatically against the **Python reference simulator** (primary golden model), with **MARS** as an independent cross-check (§11.4). MARS supports `eret` but **not** `di`/`ei`.

### 2.3 RTL / Structural Level

`cpu.v` is **strictly split** into:

- **Control Unit:** purely combinational decoder.
- **Datapath:** PC, register file, ALU, extenders, multiplexers, EPC, IE.

They communicate **only** through explicit, named ports:

- **Control Word** (CU → Datapath): `RegWrite`, `RegDst`, `ALUSrc`, `ExtOp`, `MemRead`, `MemWrite`, `WBSrc`, `PCSrc[2:0]`, `ALUCtrl[3:0]`, `IEWrite`, `IEVal`.
- **Status Signals** (Datapath → CU): `o_zero`; in Phase 2, `irq_take` (= `i_irq && ie_r`).

---

## 3. Hardware Platform and Tools

- **FPGA board:** Digilent Zybo Z7-10 (`xc7z010clg400-1`): 17,600 LUTs | 35,200 flip-flops | 270 KB Block RAM. Board I/O: push-buttons, slide switches, LEDs. Only the Programmable Logic is used.
- **Clocking:** 125 MHz oscillator (pin `K17`, 8 ns constraint). A **Clocking Wizard (MMCM)** generates the **50 MHz** CPU clock. Clocks are never divided with logic.
- **Hardware IDE:** Xilinx Vivado, synthesizable Verilog-2001, XSim behavioural simulation.
- **Memories:** `xpm_memory_sprom` (IMEM) and `xpm_memory_spram` (DMEM), `MEMORY_PRIMITIVE("distributed")`, `READ_LATENCY_A(0)` (combinational reads for single-cycle).
- **Register file:** 32 × 32 bits, flip-flops or distributed RAM (asynchronous reads), never Block RAM.
- **Software:** Python 3 (toolchain), MARS (cross-check only).
- **Reference manual:** *MIPS32 Architecture For Programmers, Volume II-A* (MD00086), Release 2–5 edition (contains `ERET`, `DI`, `EI`).

---

## 4. ISA Specification (25 mnemonics, 24 encodings)

### 4.1 Class-Wide Base ISA (16 instructions)

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
| 11 | `lw rt, imm(rs)` | `6'h23` | `rt = MEM[rs + SignExt(imm)]` |
| 12 | `sw rt, imm(rs)` | `6'h2B` | `MEM[rs + SignExt(imm)] = rt` |
| 13 | `beq rs, rt, label` | `6'h04` | `if (rs == rt) PC = (PC + 4) + (SignExt(imm) << 2)` |
| 14 | `bne rs, rt, label` | `6'h05` | `if (rs != rt) PC = (PC + 4) + (SignExt(imm) << 2)` |

**J-Type** (`[31:26] opcode | [25:0] instr_index`)

| # | Instr | opcode | Semantics |
|---|---|---|---|
| 15 | `j label` | `6'h02` | `PC = {(PC + 4)[31:28], instr_index, 2'b00}` |
| 16 | `jal label` | `6'h03` | `$ra = PC + 4; PC = {(PC + 4)[31:28], instr_index, 2'b00}` |

### 4.2 Group-Selected Extensions (9 mnemonics, 8 encodings)

**R-Type** (`opcode = 6'h00`)

| # | Instr | funct | Semantics |
|---|---|---|---|
| 17 | `nor rd, rs, rt` | `6'h27` | `rd = ~(rs \| rt)` |
| 18 | `sltu rd, rs, rt` | `6'h2B` | `rd = (rs < rt) ? 1 : 0` (unsigned) |

**I-Type**

| # | Instr | opcode | Semantics |
|---|---|---|---|
| 19 | `andi rt, rs, imm` | `6'h0C` | `rt = rs & ZeroExt(imm)` |
| 20 | `ori rt, rs, imm` | `6'h0D` | `rt = rs \| ZeroExt(imm)` |
| 21 | `xori rt, rs, imm` | `6'h0E` | `rt = rs ^ ZeroExt(imm)` |
| 22 | `lui rt, imm` | `6'h0F` | `rt = imm << 16`; `rs = 00000` |

**COP0** (`opcode = 6'h10`; R-type-like layout, decoded by opcode, **not** inside the R-type case)

| # | Instr | Fields | Encoding | Semantics |
|---|---|---|---|---|
| 23 | `eret` | `010000 \| CO=1 \| 0 (24–6) \| 011000` | `0x42000018` | `PC = EPC; IE = 1` (atomic) |
| 24 | `di` | `010000 \| 01011 \| rt=00000 \| 01100 \| 00000 \| sc=0 \| 00 \| 000` | `0x41606000` | `IE = 0` |
| 25 | `ei` | `010000 \| 01011 \| rt=00000 \| 01100 \| 00000 \| sc=1 \| 00 \| 000` | `0x41606020` | `IE = 1` |

Notes on COP0 instructions:
- `di`/`ei` are one encoding (MFMC0) that differs only in bit 5 (`sc`); hardware: `IE ← instr[5]`.
- Real MIPS32 `di rt`/`ei rt` also copy Status into `rt`. **We only support `rt = $zero`** (the argument-less form), so that write is discarded and behaviour is identical to MIPS32. The assembler rejects `di rt`/`ei rt` with a non-zero `rt`.
- `di` takes effect **immediately**: no interrupt is taken after `di` executes (must also hold in a pipelined version, without an `ehb` barrier).
- `eret` and `di`/`ei` write no GPR and no memory, and do not use the ALU.
- No privilege modes: the MIPS "Coprocessor Unusable" exception is not implemented.
- Usage rule: the interrupt handler does not use `di`/`ei` (IE is already 0 inside the handler, and `eret` restores it).

**Rationale for the extensions:**
- `lui` + `ori`: any 32-bit constant in two instructions; `ori` zero-extends, so the low half never corrupts the high half.
- `andi` / `ori` / `xori`: test, set and toggle bits with immediates, without a mask register.
- `nor`: NOT (`nor rd, rs, $zero`) and clearing bits anywhere in the 32-bit word (with `and`).
- `sltu`: correct comparison of unsigned values and addresses (e.g., `0xFFFF_xxxx`).
- `eret`: atomic return from interrupt; avoids the race of "enable IE" + `jr`.
- `di` / `ei`: enable interrupts at boot and protect critical sections (data shared with the handler). One decode case, reuses the IE flip-flop.

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
| `$k0`–`$k1` | 26–27 | Reserved for the interrupt handler |
| `$gp` | 28 | Global pointer |
| `$sp` | 29 | Stack pointer |
| `$fp` | 30 | Frame pointer |
| `$ra` | 31 | Return address (written by `jal`) |

- Address `5'b00000` reads `32'b0`; writes ignored.
- **2 asynchronous read ports** (`rs`, `rt`); **1 synchronous write port**, enabled by `i_reg_write && i_en`.
- **RegDst mux (3 inputs):** `rt`, `rd`, `5'd31`.
- **Write-data mux (3 inputs):** ALU result, DMEM read data, `PC + 4`.
- Registers are not reset (except optionally in simulation).

### 5.1 Special CPU State (COP0 subset)

| Register | Width | Reset | Written by | Read by |
|---|---|---|---|---|
| `epc_r` | 32 | `32'h0` | interrupt entry (Phase 2): `EPC ← PC` | `eret` (PC source) |
| `ie_r` | 1 | `1'b0` | `ei` (1), `di` (0), `eret` (1), interrupt entry (0) | interrupt logic (Phase 2) |

- Both are updated only when `i_en = 1`.
- Software cannot read or write EPC directly (no `mfc0`/`mtc0`).
- Boot sequence: IE starts at 0; software enables interrupts with `ei` when ready.

---

## 6. Control Unit

Purely combinational (`always @(*)`), decoding `opcode`, `funct`, and for COP0 the `rs`/`rd` fields and bit 5. All outputs default to safe values (no writes, `PCSrc = PC+4`, `IEWrite = 0`); every `case` has a `default:`. Unknown encodings behave as `nop`.

| Instruction | RegWrite | RegDst | ALUSrc | ExtOp | MemRead | MemWrite | WBSrc | PCSrc | IEWrite | IEVal |
|---|---|---|---|---|---|---|---|---|---|---|
| add, sub, and, or, xor, nor, slt, sltu | 1 | rd | reg | – | 0 | 0 | ALU | PC+4 | 0 | – |
| sll, srl | 1 | rd | reg | – | 0 | 0 | ALU | PC+4 | 0 | – |
| addi | 1 | rt | imm | sign | 0 | 0 | ALU | PC+4 | 0 | – |
| andi, ori, xori, lui | 1 | rt | imm | zero | 0 | 0 | ALU | PC+4 | 0 | – |
| lw | 1 | rt | imm | sign | 1 | 0 | Mem | PC+4 | 0 | – |
| sw | 0 | – | imm | sign | 0 | 1 | – | PC+4 | 0 | – |
| beq, bne | 0 | – | reg | sign | 0 | 0 | – | branch | 0 | – |
| j | 0 | – | – | – | 0 | 0 | – | jump | 0 | – |
| jal | 1 | $31 | – | – | 0 | 0 | PC+4 | jump | 0 | – |
| jr | 0 | – | – | – | 0 | 0 | – | rs | 0 | – |
| eret | 0 | – | – | – | 0 | 0 | – | EPC | 1 | 1 |
| di | 0 | – | – | – | 0 | 0 | – | PC+4 | 1 | 0 |
| ei | 0 | – | – | – | 0 | 0 | – | PC+4 | 1 | 1 |

- `di`/`ei` share one decode case: `IEVal = instr[5]`.
- `PCSrc = branch` selects the branch target only when taken (`beq`: `o_zero = 1`; `bne`: `o_zero = 0`), otherwise PC+4.
- "–" = don't care, but the RTL still drives a defined default.
- COP0 decode: `opcode == 6'h10` and
  - `eret`: `instr[25] == 1` and `funct == 6'h18`
  - `di`/`ei`: `rs == 5'b01011` and `rd == 5'b01100`

### 6.1 Next-PC Logic (PCSrc, 3 bits)

| PCSrc | Next PC | Used by |
|---|---|---|
| `000` | PC + 4 | sequential execution |
| `001` | (PC+4) + (SignExt(imm) << 2) | beq, bne (if taken) |
| `010` | {(PC+4)[31:28], index, 00} | j, jal |
| `011` | rs | jr |
| `100` | EPC | eret |
| `101`–`111` | reserved | interrupt vector (Phase 2) |

---

## 7. ALU

Combinational, 4-bit control, 11 operations, 5 free codes. **Unchanged** by `eret`/`di`/`ei`.

| ALUCtrl | Operation | Function | Used by |
|---|---|---|---|
| `0000` | AND | `A & B` | and, andi |
| `0001` | OR | `A \| B` | or, ori |
| `0010` | ADD | `A + B` | add, addi, lw, sw |
| `0011` | XOR | `A ^ B` | xor, xori |
| `0100` | SLL | `B << shamt` | sll |
| `0101` | SRL | `B >> shamt` | srl |
| `0110` | SUB | `A - B` | sub, beq, bne |
| `0111` | SLT | `A < B` (signed) | slt |
| `1000` | NOR | `~(A \| B)` | nor |
| `1001` | SLTU | `A < B` (unsigned) | sltu |
| `1010` | LUI | `B << 16` | lui |
| `1011`–`1111` | — | reserved | — |

- `o_zero = (o_y == 32'b0)`; `beq`/`bne` reuse SUB and `o_zero`.
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
- Critical path: PC → IMEM → register read → ALU → DMEM → write-back mux. Check WNS ≥ 0 at 50 MHz; if it fails, lower the MMCM frequency.
- **Reset:** synchronous, active-high `i_rst`; PC ← `0`, EPC ← `0`, IE ← `0`.
- **Step/enable:** `i_en` gates **all** state updates (PC, register file, DMEM, EPC, IE).
- Cost of `eret`/`di`/`ei`: 33 FFs (EPC + IE), a 5-input PC mux, a few LUTs of decode.

### 8.4 Naming Conventions
`i_` inputs, `o_` outputs, `_r` registers, `u_` instances, `UPPER_CASE` parameters and macros.

---

## 9. Hardware Architecture & Verilog Hierarchy

1. **`soc.v` (top level):** ports `i_clk`, `i_rst`, `i_btn`, `i_sw`, `o_led`; Clocking Wizard, reset synchronizer, debouncing, step/enable logic; instantiates `u_imem`, `u_dmem`, `u_cpu`. Phase 2: address decoding, MMIO bus and interrupt controller live here, never in `cpu.v`.
2. **`instruction_memory.v` / `data_memory.v`:** byte-addressed externally, word-addressed internally (`addr_w = i_addr[AW+1:2]`, `AW = $clog2(DEPTH)`); IMEM `DEPTH = 256`, DMEM `DEPTH = 512`; DMEM drives `o_rd` only when `i_re`; word-aligned accesses only. Keep parameterized (a pipeline may switch to Block RAM).
3. **`cpu.v`:** wires `control_unit` (`u_cu`) and `datapath` (`u_dp`) through the control word and status signals only.
4. **`control_unit.v`:** §6 table plus `o_alu_ctrl[3:0]`, `o_pc_src[2:0]`, `o_ie_we`, `o_ie_val`.
5. **`datapath.v` and submodules:** `pc_reg.v`, `register_file.v`, `alu.v`, `extend.v`, `shift_left_two.v`, `mux2.v`, `mux3.v`, **`next_pc.v`** (5-input PC-source selection, §6.1), **`cop0.v`** (EPC and IE registers).

`cop0.v` reference behaviour:

```verilog
always @(posedge i_clk) begin
  if (i_rst) begin
    epc_r <= 32'b0;
    ie_r  <= 1'b0;
  end else if (i_en) begin
    if (i_irq_take) begin           // Phase 2: interrupt entry
      epc_r <= i_pc;
      ie_r  <= 1'b0;
    end else if (i_ie_we) begin     // eret / ei / di
      ie_r  <= i_ie_val;
    end
  end
end
```

---

## 10. Phase 2: MMIO and Interrupts

### 10.1 Memory-Mapped I/O & Peripheral Bus
- Address decoding in `soc.v`: `0x0000_0000`–`0x0000_07FF` DMEM (2 KB); `0xFFFF_0000` and above I/O (exact map TBD, see §13).
- XSoC-style bus: one-hot `sel[i]`, shared `addr`/`wdata`/`we`/`re`, read data through an explicit multiplexer (no internal tri-states).
- Candidate peripherals: Timer/Counter, GPIO (debouncing, edge detection), PWM, UART.

### 10.2 Interrupts (single-vector, non-nested)
- **Detection:** interrupt controller in `soc.v` (pending/mask registers, MMIO) drives one `i_irq` to the CPU.
- **Take condition:** `irq_take = i_irq && ie_r`, sampled at each instruction boundary.
- **Entry (hardware, no instruction), "cancel the current instruction":**
  - suppress RegWrite/MemWrite of the instruction at PC;
  - `EPC ← PC`;
  - `IE ← 0`;
  - `PC ← vector` (PCSrc reserved code).
  - The cancelled instruction is re-executed after `eret`. Branches and jumps need no special handling.
- **Return:** `eret` (`PC ← EPC`, `IE ← 1` in the same cycle).
- **Critical sections in main code:** `di` … `ei`.
- **Handler register saving:** `$k0`/`$k1` free to use; other registers saved to fixed DMEM addresses relative to `$zero` (e.g. `sw $t0, 0x7F0($zero)`).

---

## 11. Python Toolchain

All tools live in `tools/` and share one ISA definition.

### 11.1 Structure
- `isa.py`: single source of truth for mnemonics, formats (**R, I, J, COP0**), opcode/funct/fixed fields, operand syntax, immediate signedness, register names.
- `assembler.py`: `.asm` → `program.mem` (+ `data.mem`, listing, symbol table).
- `refsim.py`: golden model; models GPRs, PC, DMEM, **EPC, IE**.
- `run_tests.py`: assemble → XSim batch → refsim → compare.
- `tests/`: one `.asm` per test.

### 11.2 Assembler
- Two-pass; `#` comments, labels, decimal/hex/negative immediates, ABI and numeric register names.
- Directives: `.text`, `.data`, `.word`.
- Branch offset `(target - (PC + 4)) >> 2` (signed 16); jump index `target[27:2]`.
- Range checks: signed 16 for `addi`/`lw`/`sw`/branches; unsigned 16 for `andi`/`ori`/`xori`/`lui`; 0–31 for `shamt`.
- **COP0:** `eret`, `di`, `ei` take **no operands**; emit `0x42000018`, `0x41606000`, `0x41606020`. `di rt`/`ei rt` with non-zero `rt` is an error.
- Pseudo-instructions (expanded only into our ISA, `$at` as scratch): `nop`, `move`, `not`, `li`, `la`, `b`, `blt`/`bgt`/`ble`/`bge`.
- Errors with file and line; never emit a partial `.mem`.
- Output: `program.mem`, one 8-hex-digit word per line.

### 11.3 Reference Simulator
- Exact §4 semantics: no delay slots, no overflow exceptions, `$zero` hardwired, 32-bit wraparound.
- `eret`: `PC ← EPC`, `IE ← 1`. `di`: `IE ← 0`. `ei`: `IE ← 1`. EPC = 0 and IE = 0 at reset.
- Phase 2: models interrupt entry with the same "cancel the current instruction" rule.
- Outputs final registers, DMEM, EPC, IE and the committed-instruction PC trace.

### 11.4 Test Flow
1. Assemble each `tests/*.asm`.
2. Run `tb_soc.v` in XSim batch (`xvlog` → `xelab` → `xsim -R`).
3. Run `refsim.py` on the same machine code.
4. Compare registers, DMEM, **EPC, IE** and (optionally) PC trace; report the first mismatch.

**MARS cross-check:** *Settings → Memory Configuration → Compact, Text at Address 0*. Tests that use `di`/`ei` are excluded (MARS does not implement them).

### 11.5 Test Conventions
- **Halt:** self-loop `end: j end`; the testbench stops when the PC is unchanged for two cycles, or at a cycle limit (timeout = failure). See §13 for the pipeline-compatible alternative.
- **State dump:** `tb_soc.v` writes register file, DMEM, `epc_r` and `ie_r` via hierarchical references.
- **Traces:** `TRACE_PC` prints `cycle, PC, instruction`; `TRACE_REGS` prints register writes.

### 11.6 Phase 1 Test Plan
- One test per instruction, plus combined programs (loops, `jal`/`jr $ra`, stack use).
- Edge cases: writes to `$zero`; negative immediates; forward/backward and taken/not-taken branches; `slt` vs `sltu` with `0x8000_0000`; shifts by 0 and 31; `lui` + `ori` for `0xFFFF_0000` and `0x1234_5678`; `andi`/`ori`/`xori` with `0xFFFF`; `lw`/`sw` at first and last DMEM words.
- **COP0 tests:**
  - `ei`, `di`, `ei`, `di` sequences: check `ie_r` after each.
  - `eret` without interrupts: EPC = 0 after reset, so `eret` restarts at address 0 with IE = 1. Test: at address 0, check a DMEM flag; on the first pass set the flag and execute `eret`; on the second pass jump to `end`. Expected: flag set, IE = 1, end reached.
  - Encodings of `eret`/`di`/`ei` checked against `0x42000018`/`0x41606000`/`0x41606020`.

---

## 12. Pipeline Readiness (future)

Rules so a future 5-stage pipeline runs the same software and the same tests:
- No branch or load delay slots, ever (§2.1). The same `refsim.py` validates both CPUs.
- One destination register per instruction; no multi-cycle units.
- Only `beq`/`bne` compare two registers (can resolve in ID); `blt`/`bge` stay pseudo-instructions.
- Every instruction carries its PC down the pipeline (needed for EPC).
- `di`/`ei`/`eret` write IE in the **same stage** where interrupts are sampled, so `di` takes effect immediately with no `ehb`.
- `eret` flushes younger instructions like a jump.
- Control word grouped by stage: EX (`ALUCtrl`, `ALUSrc`, `ExtOp`), MEM (`MemRead`, `MemWrite`), WB (`RegWrite`, `RegDst`, `WBSrc`), plus `PCSrc`, `IEWrite`, `IEVal`.
- `next_pc.v` and `cop0.v` are separate modules; future hazard and forwarding units connect through named ports.

---

## 13. Open Items (recommended, not yet adopted)

- **I/O map in `0xFFFF_8000`–`0xFFFF_FFFF`:** every peripheral reachable as `lw/sw off($zero)` with a negative offset, in one instruction.
- **Peripheral registers with SET / CLEAR / TOGGLE and write-1-to-clear flags;** important bits in the lower 16 bits.
- **Pipeline-compatible halt:** end tests with a write to a "test done" MMIO address instead of the PC self-loop; trace committed instructions only.
- Optional instructions considered and **not** added: `slti`/`sltiu`, `sllv`/`srlv`, `bltz`/`bgez`, `mfc0`/`mtc0`, `di rt`/`ei rt` with Status read-back.

---

## 14. Guidelines for the Assistant

- Clean, synthesizable Verilog-2001 for Vivado: defaults at the top of every `always @(*)`, `default:` in every `case`, `=`/`<=` never mixed.
- Respect the naming conventions and the 25-mnemonic ISA with the encodings in §4; unused bits always `0`.
- Strict CU/Datapath separation; every new signal is a named port.
- Python 3; `isa.py` is the single source of truth. Any ISA change updates `isa.py`, `control_unit.v`, `refsim.py` and tests together.
- Phase 2 features pluggable in `soc.v` without changing `cpu.v` logic.
- Prefer designs that reuse the existing datapath and keep the CU/Datapath interface clean.
- Respect the Zybo Z7-10 constraints and the pipeline-readiness rules (§12).
