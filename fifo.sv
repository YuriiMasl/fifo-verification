// Синхронный FIFO (First In, First Out)
// Параметры: DATA_WIDTH — ширина данных, DEPTH — глубина (степень двойки)

`timescale 1ns/1ps

module fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16
) (
    input  logic                  clk,
    input  logic                  rst_n,     // сброс, активный низким уровнем
    input  logic                  wr_en,     // разрешение записи
    input  logic                  rd_en,     // разрешение чтения
    input  logic [DATA_WIDTH-1:0] data_in,   // данные для записи
    output logic [DATA_WIDTH-1:0] data_out,  // данные при чтении
    output logic                  full,      // FIFO заполнен
    output logic                  empty      // FIFO пуст
);

    localparam int PTR_WIDTH = $clog2(DEPTH); // $clog2 - округление в большую сторону

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];  // память
    logic [PTR_WIDTH:0]    wr_ptr, rd_ptr, count;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;           // сброс активен - все обнуляем
            count  <= '0;
        end 
            else begin
            // 2'b10 — только запись
            // 2'b01 — только чтение
            // 2'b11 — запись и чтение одновременно (count не меняется)
            case ({wr_en & ~full, rd_en & ~empty})
                2'b10: begin
                    mem[wr_ptr[PTR_WIDTH-1:0]] <= data_in;
                    wr_ptr <= wr_ptr + 1'b1;
                    count  <= count + 1'b1;
                end
                2'b01: begin
                    rd_ptr <= rd_ptr + 1'b1;
                    count  <= count - 1'b1;
                end
                2'b11: begin
                    mem[wr_ptr[PTR_WIDTH-1:0]] <= data_in;
                    wr_ptr <= wr_ptr + 1'b1;
                    rd_ptr <= rd_ptr + 1'b1;
                end
                default: ;
            endcase
        end
    end

    assign data_out = mem[rd_ptr[PTR_WIDTH-1:0]];

endmodule
