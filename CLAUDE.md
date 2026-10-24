# Instructions for Claude Code

This repo is a single-cycle MIPS32 SoC (Verilog-2001, Vivado, Zybo Z7-10) plus a Python toolchain.

- The authoritative specification is `docs/spec.md`. Read it before changing RTL or tools.
- `tools/isa.py` is the single source of truth for encodings. Any ISA change updates
  `isa.py`, `rtl/control_unit.v`, `tools/refsim.py` and tests together.
- Verilog rules: defaults at the top of every `always @(*)`, `default:` in every `case`,
  `=` only in combinational blocks, `<=` only in sequential blocks, one block per signal.
  Naming: `i_` inputs, `o_` outputs, `_r` registers, `u_` instances, `UPPER_CASE` parameters.
- Strict Control Unit / Datapath separation; every signal between them is a named port.
- Never commit Vivado-generated files or `.mem` files. Add new sources under `rtl/` or `sim/`
  and rebuild with `scripts/create_project.tcl` (which uses `add_files`, never `import_files`).
- Work on a feature branch and open a pull request; never push directly to `main`.
