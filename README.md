# Single-Cycle MIPS32 SoC — Zybo Z7-10

*Projecto de Arquitetura de Microprocessadores Avançada*, Universidade do Minho.
David Cardoso · Ana Sofia Cunha

A 32-bit single-cycle MIPS processor in Verilog-2001 with a Python toolchain
(assembler, reference simulator, automated XSim test runner).
Full specification: [`docs/spec.md`](docs/spec.md).

## Repository layout

| Folder | Contents |
|---|---|
| `rtl/` | Synthesizable Verilog (`soc.v`, `cpu.v`, `control_unit.v`, `datapath.v`, ...) |
| `sim/` | Testbenches (`tb_<module>.v`, `tb_soc.v`) |
| `constraints/` | `zybo_z7_10.xdc` |
| `ip/` | IP configuration (`.xci` only) |
| `scripts/` | `create_project.tcl` rebuilds the Vivado project |
| `tools/` | `isa.py`, `assembler.py`, `refsim.py`, `run_tests.py`, `tests/*.asm` |
| `docs/` | Specification and presentations |

## First-time setup

```bash
git clone <repo-url>
cd mips-soc
python -m venv .venv
# Windows: .venv\Scripts\activate   |   Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
vivado -mode batch -nojournal -nolog -source scripts/create_project.tcl
```

Open the folder in VS Code and install the recommended extensions when prompted.
For the `xvlog` linter, Vivado's `bin` folder must be on your PATH.
In Vivado, set *Tools → Settings → Text Editor → Custom Editor* to `code -g [file name]:[line number]`.

The Vivado project lives in `build/` and is **never committed**: after pulling
new source files, just run the *Rebuild Vivado project* task again.

## Workflow

1. `git switch main && git pull`
2. `git switch -c feat/<name>` (one module + its testbench, or one tool feature)
3. Commit, push, open a pull request; the other person reviews and merges.
4. Only one open branch edits `control_unit.v`, `isa.py`, `datapath.v` or `docs/spec.md` at a time.
