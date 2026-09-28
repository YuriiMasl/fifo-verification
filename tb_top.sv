// Тестбенч для верификации синхронного FIFO

`timescale 1ns/1ps

module tb_top;

    parameter int DATA_WIDTH = 8;
    parameter int DEPTH      = 16;
    parameter int NUM_OPS    = 500;

    // ---- Тактовый сигнал ----
    logic clk = 0;
    always #5 clk = ~clk;

    // ---- Сигналы DUT ----
    logic                  rst_n;
    logic                  wr_en;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] data_in;
    logic [DATA_WIDTH-1:0] data_out;
    logic                  full;
    logic                  empty;

    // ---- Экземпляр DUT ----
    fifo #(                        // #(...) - параметры
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty)
    );

    // ---- Скорборд: эталонная модель FIFO ----
    logic [DATA_WIDTH-1:0] model [$]; // [$] - очередь

    int checks = 0;
    int errors = 0;

    // ---- Счётчики покрытия (вручную) ----
    int cov_wr_1, cov_wr_0;
    int cov_rd_1, cov_rd_0;
    int cov_full_1, cov_full_0;
    int cov_empty_1, cov_empty_0;
    int cov_wr_rd_00, cov_wr_rd_01;
    int cov_wr_rd_10, cov_wr_rd_11;

    // ============================================================
    // Задача проверки: вызывается каждый такт
    // ============================================================
    task automatic check();
        logic [DATA_WIDTH-1:0] expected;

        bit real_wr = wr_en & ~full;
        bit real_rd = rd_en & ~empty;

        // Сбор покрытия
        if (wr_en) cov_wr_1++; else cov_wr_0++;
        if (rd_en) cov_rd_1++; else cov_rd_0++;
        if (full)  cov_full_1++; else cov_full_0++;
        if (empty) cov_empty_1++; else cov_empty_0++;
        case ({wr_en, rd_en})
            2'b00: cov_wr_rd_00++;
            2'b01: cov_wr_rd_01++;
            2'b10: cov_wr_rd_10++;
            2'b11: cov_wr_rd_11++;
        endcase

        // Сначала обрабатываем чтение (FIFO отдаёт старое значение)
        if (real_rd) begin
            if (model.size() == 0) begin  // .size - оператор [$],
                $error("[SCB] Read from empty model!");
                errors++;
            end else begin
                expected = model.pop_front();
                checks++;
                if (expected !== data_out) begin
                    $error("[SCB] MISMATCH: expected=0x%0h actual=0x%0h",
                           expected, data_out);
                    errors++;
                end
            end
        end

        // Затем — запись
        if (real_wr)
            model.push_back(data_in);
    endtask

    // ============================================================
    // Основной сценарий
    // ============================================================
    initial begin
        // Инициализация
        rst_n   = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = '0;

        // Сброс
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        $display("[TB] Reset done, starting random stimulus");

        // Фаза 1: случайный стимул
        for (int i = 0; i < NUM_OPS; i++) begin // i — это счётчик, который говорит: «Сделай это действие NUM_OPS (500) раз»
            @(negedge clk);
            wr_en   = $urandom_range(0, 1);
            rd_en   = $urandom_range(0, 1);
            data_in = $urandom;
            @(posedge clk);
            check();
        end

        // Фаза 2: заполнить до full
        $display("[TB] Directed test: fill to full");
        for (int i = 0; i < DEPTH + 5; i++) begin
            @(negedge clk);
            wr_en   = 1;
            rd_en   = 0;
            data_in = $urandom;
            @(posedge clk);
            check();
        end

        // Фаза 3: опустошить до empty
        $display("[TB] Directed test: drain to empty");
        for (int i = 0; i < DEPTH + 5; i++) begin
            @(negedge clk);
            wr_en = 0;
            rd_en = 1;
            @(posedge clk);
            check();
        end

        // Итоговый отчёт
        $display("========================================");
        $display("[SCB] Checks: %0d, Errors: %0d", checks, errors);
        if (errors == 0) $display("[SCB] *** TEST PASSED ***");
        else             $display("[SCB] *** TEST FAILED ***");
        $display("========================================");

        $display("[COV] wr_en: 0=%0d, 1=%0d", cov_wr_0, cov_wr_1);
        $display("[COV] rd_en: 0=%0d, 1=%0d", cov_rd_0, cov_rd_1);
        $display("[COV] full:  0=%0d, 1=%0d", cov_full_0, cov_full_1);
        $display("[COV] empty: 0=%0d, 1=%0d", cov_empty_0, cov_empty_1);
        $display("[COV] wr/rd: 00=%0d, 01=%0d, 10=%0d, 11=%0d",
                 cov_wr_rd_00, cov_wr_rd_01, cov_wr_rd_10, cov_wr_rd_11);

        $finish;
    end

    // Защита от зависания
    initial begin
        #1_000_000;
        $error("[TB] TIMEOUT!");
        $finish;
    end

endmodule
