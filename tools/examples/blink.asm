# blink.asm - pisca 1 LED (bit 0 do endereco LED_ADDR)
        .eqv  LED_ADDR, 0x1000      # SUPOSICAO: layout do GPIO por decidir
        .eqv  DELAY,    0x00BF0000  # ~0,5 s a 50 MHz (2 ciclos por volta)

        .text
        j     main                  # 0x00 reset
        j     unused_irq            # 0x04 vetor 0
        j     unused_irq            # 0x08 vetor 1
        j     unused_irq            # 0x0C vetor 2
        j     unused_irq            # 0x10 vetor 3
unused_irq:
        j     unused_irq            # nunca usado (IE = 0)

main:
        clear $t0                   # estado do LED = 0
loop:
        xori  $t0, $t0, 1           # inverte o bit 0
        sw    $t0, LED_ADDR($zero)  # escreve no LED
        li    $t1, DELAY
delay:
        addi  $t1, $t1, -1
        bgtz  $t1, delay
        j     loop