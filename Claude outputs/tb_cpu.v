`timescale 1ns / 1ps

// Testbench do cpu (control_unit + datapath) com a IMEM e a DMEM ligadas.
// O programa vem de tb_cpu.mem (gerado com tools/assembler.py a partir de tb_cpu.asm).
//
// Temporizacao (igual ao tb_datapath): clock de 10 ns, flancos de subida em 5, 15, 25...
//  - entradas do tb (rst, irq) mudam 1 ns DEPOIS do flanco
//  - os valores de cada instrucao verificam-se no flanco DESCENDENTE (meio do ciclo),
//    quando a parte combinacional ja estabilizou e antes de o flanco seguinte escrever
//  - o que o flanco escreve (registo, PC, memoria, EPC, IE) so se ve no ciclo seguinte

module tb_cpu;
    reg clk;
    reg rst;
    reg irq;
    reg [1:0] irq_id;

    wire [31:0] pc, instr;
    wire [31:0] mem_addr, mem_wd, mem_rd;
    wire mem_en, mem_rw;

    cpu u_cpu (
        .i_clk(clk), .i_rst(rst),
        .i_instr(instr), .i_mem_rd(mem_rd),
        .i_irq(irq), .i_irq_id(irq_id),
        .o_pc(pc),
        .o_mem_addr(mem_addr), .o_mem_wd(mem_wd),
        .o_mem_en(mem_en), .o_mem_rw(mem_rw)
    );

    instruction_memory #(.INIT_FILE("tb_cpu.mem")) u_imem (
        .i_addr(pc), .o_instr(instr)
    );

    data_memory u_dmem (
        .i_clk(clk), .i_en(mem_en), .i_rw(mem_rw),
        .i_addr(mem_addr), .i_wd(mem_wd), .o_rd(mem_rd)
    );

    // sinais internos que interessam ver (nao ha porta para eles)
    wire        irq_take   = u_cpu.irq_take;
    wire [31:0] write_data = u_cpu.u_datapath.write_data;  // dado do write-back

    initial clk = 0;
    always #5 clk = ~clk;

    // ---------- verificacao ----------
    integer errors = 0;
    task check;
        input [8*20-1:0] what;
        input [31:0] got, exp;
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("ERRO  t=%t  PC=%h  %0s = %h (esperado %h)", $time, pc, what, got, exp);
            end else
                $display("ok    t=%t  PC=%h  %0s = %h", $time, pc, what, got);
        end
    endtask

    // espera que o PC chegue a 'addr' e vai para o meio desse ciclo
    task at_pc;
        input [31:0] addr;
        begin
            wait (pc == addr);
            @(negedge clk);
        end
    endtask

    // o addi de 0x68 esta depois de um beq tomado: nunca pode ser buscado
    always @(negedge clk)
        if (pc == 32'h68) begin
            errors = errors + 1;
            $display("ERRO  t=%t  PC=0x68 executado (delay slot nao existe)", $time);
        end

    initial begin
        $timeformat(-9, 0, " ns", 6);
        rst = 1; irq = 0; irq_id = 2'd0;

        // ---------- 0. reset sincrono: PC e X ate ao primeiro flanco ----------
        #1  check("pc antes flanco", pc, 32'hxxxxxxxx);
        @(posedge clk); #1;
        check("pc pos reset", pc, 32'h0);
        check("instr", instr, 32'h0800_0010);           // j main
        rst = 0;

        // ---------- A. registo escrito no flanco, lido no ciclo seguinte ----------
        at_pc(32'h44); check("add t1 = t0+t0", mem_addr, 32'hA);

        // ---------- B. sw -> lw -> uso imediato ----------
        at_pc(32'h48); check("sw en", mem_en, 1); check("sw rw", mem_rw, 0);
                       check("sw addr", mem_addr, 32'h10); check("sw wd", mem_wd, 32'hA);
        at_pc(32'h4C); check("lw rw", mem_rw, 1);
                       check("lw mem_rd", mem_rd, 32'hA);      // escrito no flanco anterior
        at_pc(32'h50); check("add t3=t2+t0", mem_addr, 32'hF); // load-use sem stall

        // ---------- C. lb com sinal, byte 1 ----------
        at_pc(32'h60); check("lb mem_rd", mem_rd, 32'h8081_8283);
                       check("lb write_data", write_data, 32'hFFFF_FF82);

        // ---------- D. branch tomado: o PC salta logo no flanco seguinte ----------
        at_pc(32'h64); @(posedge clk); #1; check("pc apos beq", pc, 32'h6C);
        at_pc(32'h70); check("t6 = 0 (sem addi)", mem_addr, 32'h0);

        // ---------- E. jal / jr ----------
        at_pc(32'h74); check("jal write_data", write_data, 32'h78);  // $ra = PC + 4
        at_pc(32'h98); @(posedge clk); #1; check("pc apos jr", pc, 32'h78);
        at_pc(32'h78); check("s2 = v0", mem_addr, 32'h7);

        // ---------- F. interrupcao ----------
        wait (pc == 32'h7C); #1; irq = 1; irq_id = 2'd2;  // 1 ns depois do flanco
        @(negedge clk); check("irq_take IE=0", irq_take, 0);
        at_pc(32'h80);  check("irq_take ei", irq_take, 0);     // IE so muda no flanco
        at_pc(32'h84);  check("irq_take shadow", irq_take, 0); // ei_shadow protege esta
        at_pc(32'h88);  check("irq_take", irq_take, 1);
                        check("sw cancelado", mem_en, 0);
        @(posedge clk); #1;
        check("pc vetor 2", pc, 32'h0C);
        irq = 0;                                               // fonte "atendida"
        at_pc(32'h9C);  check("mfc0 EPC", write_data, 32'h88);
        at_pc(32'hA8);  @(posedge clk); #1; check("pc retorno", pc, 32'h88);
        @(negedge clk); check("sw repetido en", mem_en, 1); check("sw wd", mem_wd, 32'h2);
        at_pc(32'h8C);  check("lw s3", mem_rd, 32'h2);

        at_pc(32'h90);
        if (errors == 0) $display("=== tb_cpu: todos os testes passaram ===");
        else             $display("=== tb_cpu: %0d ERRO(S) ===", errors);
        $finish;
    end

    // rede de seguranca: se o PC se perder, o tb nao fica a correr para sempre
    initial begin #5000; $display("TIMEOUT: PC = %h", pc); $finish; end
endmodule
