# MIPS32 em Verilog — Zybo Z7-10

*Projeto de Arquitetura de Microprocessadores Avançada*, Universidade do Minho.
David Cardoso · Ana Sofia Cunha

Processador MIPS de 32 bits em Verilog-2001, desenvolvido bloco a bloco para a
placa Zybo Z7-10 (Zynq-7010, `xc7z010clg400-1`). Suporta interrupções através de
um coprocessador 0 simplificado (EPC, enable de interrupções, `ei`/`di`) e loads
em dois ciclos.

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| `rtl/` | Módulos sintetizáveis |
| `sim/` | Testbenches (`tb_<módulo>.v`) |
| `scripts/` | `create_project.tcl`, que recria o projeto Vivado |

### Módulos (`rtl/`)

| Ficheiro | Função |
|---|---|
| `datapath.v` | Datapath: liga PC, banco de registos, ALU, extensões, CP0 e muxes de write-back |
| `alu.v` | ALU de 32 bits (AND, OR, ADD, XOR, SLL, SRL, SUB, SLT, NOR, LUI) |
| `register_file.v` | Banco de 32 registos, `$0` sempre a zero (usa o IP `rf_dpram`) |
| `next_pc.v` | Cálculo do próximo PC: PC+4, branch, jump, `jr` e vetores de interrupção |
| `cop0.v` | Coprocessador 0: EPC, enable de interrupções e pedido de interrupção |
| `sign_ext.v` | Extensão do imediato de 16 bits (com sinal ou com zeros) |
| `load_ext.v` | Seleção de byte e extensão de sinal para `lb` / `lw` |

### Testbenches (`sim/`)

`tb_alu.v`, `tb_cop0.v`, `tb_next_pc.v`.

## Como usar

Recriar o projeto Vivado (a partir da raiz do repositório):

```bash
vivado -mode batch -nojournal -nolog -source scripts/create_project.tcl
```

O projeto é criado em `build/vivado/mips.xpr`. Os ficheiros de `rtl/` e `sim/`
são referenciados no sítio (não copiados), por isso o que se edita no editor é
o que o Vivado sintetiza e simula. A pasta `build/` nunca é enviada para o git.

O topo de simulação por omissão é `tb_alu`; para correr outro testbench, muda o
topo do fileset `sim_1` no Vivado ou no script.

> **Nota:** `register_file.v` instancia o IP `rf_dpram` (Distributed Memory
> Generator, RAM de dupla porta). Esse IP tem de ser gerado no projeto Vivado.
