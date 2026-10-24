## What changed

<!-- Short description. Reference issues with "Closes #N". -->

## How it was tested

<!-- Testbench names, XSim result, run_tests.py output -->

## Checklist
- [ ] Testbench added/updated and passing in XSim
- [ ] If the ISA changed: `isa.py`, `control_unit.v`, `refsim.py` and tests updated together
- [ ] `docs/spec.md` updated if behaviour, encodings or ports changed
- [ ] Coding rules respected (defaults + `default:` in every `always @(*)`, `=`/`<=` never mixed, naming conventions)
- [ ] No Vivado-generated files or `.mem` files committed
