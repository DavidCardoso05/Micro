# CPU Design Notes (Revision 4)

**Date:** 2026-11-16 · **Spec:** [`spec.md`](spec.md) (Revision 4)

The spec says *what* the CPU does. This document explains *how* the RTL does it and *why*
it was written that way. Section numbers like "spec §6.3" refer to `spec.md`.

| File | What it is |
|---|---|
| [`rtl/cpu.v`](../rtl/cpu.v) | CPU core: `control_unit` + `datapath` |
| [`rtl/control_unit.v`](../rtl/control_unit.v) | Control Unit (spec §6) |
| [`rtl/datapath.v`](../rtl/datapath.v) | Datapath, including the `MemPhase` flip-flop |
| [`rtl/pc_reg.v`](../rtl/pc_reg.v) | PC register (enable = `PCWrite`) |
| [`rtl/next_pc.v`](../rtl/next_pc.v) | Next-PC selection (spec §6.2) |
| [`rtl/register_file.v`](../rtl/register_file.v) | 32 × 32 register file |
| [`rtl/alu.v`](../rtl/alu.v) | ALU (spec §7) |
| [`rtl/sign_extend.v`](../rtl/sign_extend.v) | 16 → 32 sign / zero extension |
| [`rtl/load_ext.v`](../rtl/load_ext.v) | `lw` / `lb` data extension |
| [`rtl/cop0.v`](../rtl/cop0.v) | EPC, IE, `ei_shadow`, `irq_take` |
| [`rtl/muxes.v`](../rtl/muxes.v) | `mux2_32bit`, `mux3`, `mux4` |
| [`rtl/instruction_memory.v`](../rtl/instruction_memory.v) | IMEM, 512 words, asynchronous read |
| [`rtl/data_memory.v`](../rtl/data_memory.v) | DMEM, 512 words, synchronous read and write |

---

## 1. Why loads take two cycles

The DMEM is a block RAM, and a block RAM reads synchronously: the address is captured on a
clock edge and the data appears after that edge. A purely single-cycle `lw` would need a
combinational read (distributed RAM), which is what revision 3 used.

Revision 4 keeps the block RAM and stretches `lw`/`lb` to two cycles instead. Everything else
stays single-cycle, so the CPU is still easy to follow: one instruction at a time, no pipeline,
no hazards, no delay slots. The cost is one flip-flop (`MemPhase`) and a few gates in the CU.

### 1.1 The mechanism

```verilog
// control_unit.v (combinational)
wire mem_wait = dec_mem_enable & dec_mem_rw & ~i_mem_phase & ~i_irq_take;
assign o_pc_write   = ~mem_wait;
assign o_reg_write  = dec_reg_write  & ~i_irq_take & ~mem_wait;
assign o_mem_enable = dec_mem_enable & ~i_irq_take & ~i_mem_phase;

// datapath.v (sequential)
always @(posedge i_clk)
    if (i_rst) mem_phase_r <= 1'b0;
    else       mem_phase_r <= ~i_pc_write;
```

`MemPhase` is 1 exactly in the cycle after one where the PC was held. The only thing that holds
the PC is `MemWait`, so `MemPhase = 1` means "second cycle of a load".

### 1.2 Timing of `lw $t2, 0($t0)` at `0x0C`

Measured in `sim/tb_cpu.v` (inputs change on falling edges, state on rising edges):

| Cycle | PC | MemPhase | PCWrite | MemEnable | RegWrite | At the rising edge that ends the cycle |
|---|---|---|---|---|---|---|
| 1 | `0C` | 0 | 0 | 1 | 0 | DMEM captures `mem[2]` into its output register; `MemPhase ← 1` |
| 2 | `0C` | 1 | 1 | 0 | 1 | `$t2 ← load_ext(o_rd)`; PC ← `10`; `MemPhase ← 0` |

### 1.3 Decisions

- **`MemPhase` lives in the datapath, not the CU.** The CU stays purely combinational (spec §6);
  all state is in the datapath and goes back to the CU as a status signal.
- **`PCWrite` is a separate signal from `PCSrc`.** `PCSrc` chooses *which* address; `PCWrite`
  decides *whether* the PC is written. Mixing the two (for example a "PC hold" code in `PCSrc`)
  would make `next_pc` know about loads.
- **`MemEnable = 0` in the second cycle.** The block RAM output register only changes when
  enabled, so it keeps the word read in cycle 1. This guarantees that a load touches the memory
  once, which matters for peripherals whose reads have side effects (spec §10.1).
- **The register file is not touched.** `RegWrite = 0` in cycle 1 is enough; the register file
  keeps `i_we` as its only enable.
- **Base register overwritten by the load** (`lw $t0, 0($t0)`): the write happens at the end of
  cycle 2, so the address stays correct during both cycles.
- **`sw` does not wait.** A synchronous write needs only one edge; `MemRW = 0` keeps `MemWait = 0`.

---

## 2. Interrupts and the load wait

```verilog
// cop0.v
assign o_irq_take = i_irq & ie_r & ~ei_shadow_r & ~i_mem_phase;
```

- **Cycle 1 of a load can be interrupted.** `irq_take` removes `MemWait`, so `PCWrite = 1` and
  the vector is loaded; `MemEnable` and `RegWrite` are 0, so the load leaves no trace. EPC gets
  the load's PC and the load is re-executed after the return.
- **Cycle 2 of a load cannot.** The memory has already been read; cancelling now would read it a
  second time after the return.
- **Cancellation** (spec §6.4) is three AND gates in the CU (`RegWrite`, `MemEnable`, `IEWrite`)
  plus `PCSrc = 100`. `cop0.v` writes `EPC ← PC`, `IE ← 0`, `ei_shadow ← 0` on the same edge.
- The vector wins over any branch or jump; the cancelled branch or jump is re-executed after
  the return.

### 2.1 `ei` shadow

`ei_shadow_r <= ie_we & ie_val` is set by `ei` and cleared by any other instruction. It blocks
`irq_take` for one instruction, so the return sequence `mfc0 $k0,$14 ; ei ; jr $k0` cannot be
interrupted between `ei` and `jr` (spec §10.2).

In the waveform of `sim/tb_cop0.v`, `irq_take` rises in the second half of the cycle after `ei`:
the shadow is cleared on the rising edge in the middle of that testbench step, and from that
edge on it is already the next instruction. `cop0` only samples `irq_take` on rising edges, and
there it is 0.

---

## 3. Control Unit (`rtl/control_unit.v`)

### 3.1 Interface

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `i_opcode`, `i_rs`, `i_rt`, `i_rd`, `i_funct` | in | 6/5/5/5/6 | instruction fields |
| `i_zero` | in | 1 | ALU result is 0 |
| `i_rs_neg` | in | 1 | `rs[31]`, from register-file port A |
| `i_irq_take` | in | 1 | from `cop0` |
| `i_mem_phase` | in | 1 | second cycle of `lw`/`lb` |
| `o_reg_write` | out | 1 | write the register file |
| `o_reg_dst` | out | 2 | `00` rt, `01` rd, `10` $31 |
| `o_alu_src` | out | 1 | `0` rt, `1` extended immediate |
| `o_alu_ctrl` | out | 4 | ALU operation |
| `o_ext_op` | out | 1 | `0` zero-extend, `1` sign-extend |
| `o_mem_enable` | out | 1 | DMEM access |
| `o_mem_rw` | out | 1 | `1` read, `0` write |
| `o_load_byte` | out | 1 | `0` lw, `1` lb |
| `o_wb_src` | out | 2 | `00` ALU, `01` load_ext, `10` PC+4, `11` EPC |
| `o_pc_src` | out | 3 | spec §6.2 |
| `o_pc_write` | out | 1 | enable of the PC register |
| `o_ie_we`, `o_ie_val` | out | 1/1 | `di` / `ei` |

### 3.2 Structure: four parts

```
 instruction fields ──► [1. Decode] ──► control word
                              │
                              ├── dec_branch ──► [2. Branch condition] ◄── i_zero, i_rs_neg
                              │                         │ branch_taken
                              ├── dec_pc_src ──► [3. PC select] ◄── i_irq_take
                              │
                              └── dec_reg_write, dec_mem_enable, dec_mem_rw, dec_ie_we
                                         ──► [4. Load wait + cancellation] ◄── i_irq_take, i_mem_phase
                                                   │
                                  o_reg_write, o_mem_enable, o_mem_rw, o_pc_write, o_ie_we
```

1. **Decode** (`always @(*)`): looks only at the instruction fields.
2. **Branch condition** (`always @(*)`): a `case` on `dec_branch` (spec §6.1).
3. **PC select** (`always @(*)`): vector, branch target or `dec_pc_src`.
4. **Load wait and cancellation** (`assign`s, §1.1 above).

Why split it:
- **The control word depends only on the instruction.** Only `o_pc_src` and the enables depend on
  status signals, and they are all computed in parts 2–4.
- **No false combinational loop.** `i_zero` comes from the ALU, which is controlled by
  `o_alu_ctrl`. With the split, `o_alu_ctrl` structurally cannot depend on `i_zero`.

### 3.3 Decoding the fixed fields

Unknown encodings behave as `nop`. Besides opcode and funct, the CU checks only the fixed fields
listed in spec §6 (`rt` for `bgez`/`bgtz`; `rs`, `rd`, `sel` for COP0). It does not check
unused bits such as `shamt` on `add`: the assembler guarantees they are 0.

### 3.4 Branches

- **`bgtz`**: `rt = 00000`, so ALU port B reads `$zero` and `i_zero` means `rs == 0`.
  `bgtz` = "not negative and not zero". No comparator is added.
- **`bgez`**: `rt = 00001`, so port B reads `$at`. That is why `bgez` uses **only** `i_rs_neg`.
- `i_rs_neg` comes from the register file, not the ALU, so it is correct even when port B holds
  an unrelated value.

---

## 4. ALU (`rtl/alu.v`)

- **One shared adder** for ADD, SUB and SLT (spec §8.3). SUB is `A + ~B + 1`: when `sub_en = 1`,
  B is inverted and the `+1` is the carry-in.
- **SLT without an overflow bug.** "A < B if the sign of A − B is 1" is wrong when A − B
  overflows (`0x80000000 − 1 = 0x7FFFFFFF`). The ALU uses:
  ```verilog
  lt_signed = (i_a[31] != i_b[31]) ? i_a[31]   // different signs: the negative one is smaller
                                   : sum[31];  // same signs: A - B cannot overflow
  ```
- **LUI is `{i_b[15:0], 16'b0}`**: only wiring, no shifter.
- **Reserved codes give 0**, including `1001` (old SLTU).
- **`o_zero` is computed from `o_y`**, so it is valid for every operation.

---

## 5. Next PC (`rtl/next_pc.v`) and PC register (`rtl/pc_reg.v`)

- **`next_pc` is a plain multiplexer.** The CU decides whether a branch is taken, so
  `PCSrc = 001` always means "go to the branch target".
- **`next_pc` takes the raw 16-bit immediate** and does its own sign extension and `<< 2`
  (only wiring), so the branch target never depends on `ExtOp`.
- **Jumps use `(PC+4)[31:28]`**, as MIPS32 defines.
- **`jr` passes rs unchanged.** IMEM ignores the two low address bits.
- **`IRQ_VECTOR` is a parameter** with the fixed value `0x0000_0004` (spec §10.3 for the layout).
- **The next PC is an internal wire** of the datapath. IMEM is addressed by the PC itself
  (asynchronous read), so nothing outside the CPU needs the next PC.
- **`pc_reg`:** synchronous reset to `0x0000_0000`; `i_we` (= `PCWrite`) is the only enable.

---

## 6. Memories

### 6.1 `instruction_memory.v`

- 512 × 32, asynchronous read: `o_instr = mem[i_addr[10:2]]`. Vivado maps it to LUTs
  (distributed ROM), so the instruction at the PC is available in the same cycle.
- Initialised with `$readmemh(INIT_FILE)`; unfilled words are 0 (`nop`). No clock port.

### 6.2 `data_memory.v`

```verilog
always @(posedge i_clk) if (i_en && i_we) mem[idx] <= i_wd;   // write
always @(posedge i_clk) if (i_en)         rd_r     <= mem[idx]; // read (read-first)
assign o_rd = rd_r;
```

- Two `always` blocks, one per signal (spec §8.1). Vivado infers one RAMB18 from this pattern.
- **Read-first:** on a write, `o_rd` receives the *old* value. The CPU never uses `o_rd` after a
  `sw`, so the choice does not matter; read-first is what the code above gives naturally.
- **No reset.** Block RAM contents cannot be reset; `rd_r` starts at 0 in simulation.
- The CPU exports `MemEnable` and `MemRW`; the memory wants `i_en` and `i_we`. The glue
  `we = enable & ~rw` belongs to `soc.v` (in `tb_cpu.v` it is written in the port map).

---

## 7. Register file, extenders, muxes

- **`register_file.v`:** unchanged from the authors' version. `i_we` is the only enable,
  reads are combinational, register 0 is forced to 0 on read, synchronous reset to 0.
- **`load_ext.v`:** a `case` on `addr[1:0]` picks the byte (little-endian), then
  `{{24{b[7]}}, b}` for `lb`; `lw` passes the word.
- **`muxes.v`:** `mux2_32bit`, `mux3 #(W)` (RegDst, `W = 5`) and `mux4 #(W)` (write-back).
  `mux3` code `11` selects input A. `mux2_5bit` was removed (unused).

---

## 8. Testbenches (`sim/`)

All testbenches follow spec §2.2: stimuli only, one comment per case saying what the waveform
shows. `tb_alu.v` and `tb_register_file.v` are the style reference.

| Testbench | What it shows |
|---|---|
| `tb_alu` | ADD, AND, XOR, SLL, SRL, LUI cases |
| `tb_register_file` | writes and reads, `$0` ignored, `$31` |
| `tb_sign_extend` | `0x7FFF` / `0x8000` with sign and zero extension |
| `tb_muxes` | every select value of `mux2_32bit`, `mux3`, `mux4` |
| `tb_load_ext` | `lw`; `lb` at the four byte offsets, positive and negative bytes |
| `tb_next_pc` | every `PCSrc` code, forward and backward branch, jump region from PC+4 |
| `tb_pc_reg` | reset, `PCWrite = 1` advances, `PCWrite = 0` holds |
| `tb_instruction_memory` | asynchronous read, unaligned address, last word, wrap-around |
| `tb_data_memory` | one-cycle read latency, read-first on write, `i_en = 0`, last word |
| `tb_cop0` | IE = 0 ignores IRQ, `ei` shadow, `MemPhase` blocks, interrupt entry, `di` |
| `tb_control_unit` | one case per instruction; `lw`/`lb` with MemPhase 0 and 1; `sw`; taken / not-taken branches; `irq_take` on `add`, `lw`, `sw`, `ei`; unknown opcode |
| `tb_cpu` | CPU + both memories running `addi`, `sw`, `lw`, `lb`, `add`, `j` |

`tb_instruction_memory` and `tb_cpu` write the program directly into `mem[...]` after `#1`, so
they need no `.mem` file (XSim prints a harmless warning that `program.mem` is missing).

**How to run** (Vivado `bin` on the PATH; run it in a scratch folder so `xsim.dir/` does not
land in the repo):

```bash
xvlog rtl/*.v sim/tb_cpu.v
xelab -debug typical tb_cpu -s tb_cpu_snap
xsim tb_cpu_snap -gui
```

---

## 9. Verification status (2026-11-16)

| Check | Tool | Result |
|---|---|---|
| Compile all `rtl/` and `sim/` | `xvlog` 2024.2 | no errors, no warnings |
| Elaborate every testbench | `xelab` 2024.2 | no errors, no warnings |
| Run every testbench to `$finish` | `xsim` 2024.2 | all 12 finish |
| Waveform values vs. testbench comments | `xsim` Tcl probe (outside the repo) | all match |
| Lint, top `cpu` | `verilator --lint-only -Wall` 5.020 | only "`i_instr[31:26]` unused in datapath" (expected: the opcode goes to the CU) |
| Synthesis, top `cpu`, out of context | Vivado 2024.2 | 0 latches, 1059 FFs (31×32 register file + 32 PC + 34 COP0 + 1 MemPhase), ~1200 LUTs |
| Synthesis, top `data_memory` | Vivado 2024.2 | one RAMB18, no LUTs |

Not verified: timing (WNS) on the board, IMEM loaded from a real `program.mem`, an interrupt
running on the whole CPU (covered only by `tb_control_unit` and `tb_cop0`).

---

## 10. Open items

| # | Item |
|---|---|
| 1 | `soc.v`, address decoder, GPIO, Timer, interrupt source (Phase 2) |
| 2 | `assembler.py`, `refsim.py`, `run_tests.py` (spec §11) |
| 3 | Assembler check of the program layout (spec §10.3) |
| 4 | `scripts/create_project.tcl` still selects `control_unit` as the top when `soc.v` is missing |
| 5 | ALU / PCSrc codes are `localparam`s copied in `alu.v`, `control_unit.v`, `next_pc.v` and the testbenches. A shared `` `include `` would remove the copies but needs include paths in Vivado and XSim |
