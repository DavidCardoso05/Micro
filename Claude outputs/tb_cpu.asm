# Programa de teste do tb_cpu: cada bloco exercita um ponto critico de temporizacao.
        .text
        .org 0x00
        j    main            # reset -> PC = 0
        .org 0x04            # vetores de interrupcao: 0x04 + 4*irq_id
        j    handler         # irq_id = 0
        j    handler         # irq_id = 1
        j    handler         # irq_id = 2
        j    handler         # irq_id = 3

        .org 0x40
main:
# A. escrita no registo no flanco; a instrucao seguinte ja le o valor novo
        addi $t0, $zero, 5       # t0 = 5
        add  $t1, $t0, $t0       # t1 = 10
# B. sw -> lw no mesmo endereco, e load-use logo a seguir (sem stall)
        sw   $t1, 0x10($zero)    # MEM[0x10] = 10
        lw   $t2, 0x10($zero)    # t2 = 10
        add  $t3, $t2, $t0       # t3 = 15
# C. lb: byte 1 de 0x80818283 (little-endian) com sinal
        lui  $t4, 0x8081
        xori $t4, $t4, 0x8283    # t4 = 0x80818283
        sw   $t4, 0x14($zero)
        lb   $t5, 0x15($zero)    # t5 = 0xFFFFFF82
# D. branch tomado: SEM delay slot, a instrucao seguinte nao corre
        beq  $t0, $t0, skip
        addi $t6, $zero, 0x0BAD  # NAO pode executar
skip:   bne  $t0, $t0, main      # nao tomado
        add  $t6, $t6, $zero     # t6 = 0 (prova que o addi nao correu)
# E. jal / jr: $ra = PC + 4 escrito no flanco
        jal  func
        add  $s2, $v0, $zero     # s2 = 7 (valor de func)
# F. interrupcoes (o tb poe irq = 1 quando o PC chega a pre_ei)
pre_ei: addi $s0, $zero, 1       # IE = 0: irq ignorado
        ei
        addi $s0, $s0, 1         # protegida pelo ei_shadow
        sw   $s0, 0x20($zero)    # interrompida: cancelada (mem_en = 0), EPC = este PC
        lw   $s3, 0x20($zero)    # depois do retorno: s3 = 2
fim:    j    fim

func:   addi $v0, $zero, 7
        jr   $ra

handler:
        mfc0 $k0, $14            # k0 = EPC
        addi $s1, $s1, 1         # conta interrupcoes
        ei
        jr   $k0                 # protegida pelo ei_shadow
