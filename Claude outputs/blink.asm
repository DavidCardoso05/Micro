# blink.asm - o MIPS conta em binario nos 4 LEDs (LD0 pisca, LD1 a metade, ...)
# LEDs mapeados em memoria: sw para 0xFFFFFFF0 escreve nos LEDs (bits [3:0]).
#
# DELAY: com o CPU a 25 MHz e 2 ciclos por volta do ciclo de espera,
#   6_250_000 voltas = 12_500_000 ciclos = 0,5 s  -> LD0 muda a cada 0,5 s
# Para simular, gera outra versao com DELAY pequeno (ex.: 3).

        .eqv LEDS,  -16           # 0xFFFFFFF0 = $zero + SignExt(-16)
        .eqv DELAY, 6250000

        .text
        .org 0x00
        j    main                 # reset -> PC = 0
        .org 0x04                 # vetores de interrupcao (nao usados: irq = 0)
        j    main
        j    main
        j    main
        j    main

        .org 0x40
main:   addi $s0, $zero, 0        # contador mostrado nos LEDs
loop:   sw   $s0, LEDS($zero)     # LEDs <- s0[3:0]
        li   $t1, DELAY
wait:   addi $t1, $t1, -1
        bne  $t1, $zero, wait     # 2 ciclos por volta
        addi $s0, $s0, 1
        j    loop
