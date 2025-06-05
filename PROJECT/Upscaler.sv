`timescale 1ns / 1ps

module Upscaler (
    input  logic        VGA_SIZE,
    input  logic        vga_clk,
    input  logic        reset,
    input  logic [ 9:0] x_coor,
    input  logic [ 8:0] y_coor, // y_coor 비트 폭 확인 필요 (탑모듈과 일치)
    input  logic [11:0] base_data,
    output logic [11:0] up_scale_data
);

    localparam QVGA_WIDTH     = 320;
    localparam QVGA_HEIGHT    = 240;
    localparam QVGA_X_MAX_IDX = QVGA_WIDTH - 1;
    localparam QVGA_Y_MAX_IDX = QVGA_HEIGHT - 1;

    (* ram_style = "true_dual_port" *) logic [11:0] line_buffer_A[0:QVGA_X_MAX_IDX];
    (* ram_style = "true_dual_port" *) logic [11:0] line_buffer_B[0:QVGA_X_MAX_IDX];

    logic [$clog2(QVGA_WIDTH)-1:0]  linebuffer_waddr_x;
    logic [$clog2(QVGA_HEIGHT)-1:0] linebuffer_waddr_y;

    logic [$clog2(QVGA_WIDTH)-1:0]  x_in_floor;
    logic [$clog2(QVGA_HEIGHT)-1:0] y_in_floor;
    logic is_x_frac;
    logic is_y_frac;

    logic [11:0] p00, p10, p01, p11;
    logic [ 3:0] r00, g00, b00, r10, g10, b10;
    logic [ 3:0] r01, g01, b01, r11, g11, b11;
    logic [ 4:0] r_interp_top, g_interp_top, b_interp_top;
    logic [ 4:0] r_interp_bottom, g_interp_bottom, b_interp_bottom;
    logic [ 3:0] red_interpolated, green_interpolated, blue_interpolated;
    logic [11:0] line_top[0:QVGA_X_MAX_IDX];
    logic [11:0] line_bottom[0:QVGA_X_MAX_IDX];


    logic [11:0] processed_data_comb;

    always_ff @(posedge vga_clk or posedge reset) begin
        if(reset) begin
            linebuffer_waddr_x <= 0;
            linebuffer_waddr_y <= 0;
        end else begin
            if (VGA_SIZE) begin
                if (linebuffer_waddr_y[0]) begin
                    line_buffer_B[linebuffer_waddr_x] <= base_data;
                end else begin
                    line_buffer_A[linebuffer_waddr_x] <= base_data;
                end

                if (linebuffer_waddr_x == QVGA_X_MAX_IDX) begin
                    linebuffer_waddr_x <= 0;
                    if (linebuffer_waddr_y == QVGA_Y_MAX_IDX) begin
                        linebuffer_waddr_y <= 0;
                    end else begin
                        linebuffer_waddr_y <= linebuffer_waddr_y + 1;
                    end
                end else begin
                    linebuffer_waddr_x <= linebuffer_waddr_x + 1;
                end
            end
        end
    end

    always_comb begin
        if (VGA_SIZE) begin
            x_in_floor = x_coor >> 1;
            y_in_floor = y_coor >> 1;
            is_x_frac  = x_coor[0];
            is_y_frac  = y_coor[0];

            if (y_in_floor[0]) begin
                line_top    = line_buffer_B;
                line_bottom = (y_in_floor == QVGA_Y_MAX_IDX) ? line_buffer_B : line_buffer_A;
            end else begin
                line_top    = line_buffer_A;
                line_bottom = (y_in_floor == QVGA_Y_MAX_IDX) ? line_buffer_A : line_buffer_B;
            end

            p00 = line_top[x_in_floor];
            p10 = (is_x_frac && x_in_floor < QVGA_X_MAX_IDX) ? line_top[x_in_floor + 1] : p00;
            p01 = line_bottom[x_in_floor];
            p11 = (is_x_frac && x_in_floor < QVGA_X_MAX_IDX) ? line_bottom[x_in_floor + 1] : p01;

            {r00, g00, b00} = {p00[11:8], p00[7:4], p00[3:0]};
            {r10, g10, b10} = {p10[11:8], p10[7:4], p10[3:0]};
            {r01, g01, b01} = {p01[11:8], p01[7:4], p01[3:0]};
            {r11, g11, b11} = {p11[11:8], p11[7:4], p11[3:0]};

            if (is_x_frac) begin
                r_interp_top    = (r00 + r10) >> 1;
                g_interp_top    = (g00 + g10) >> 1;
                b_interp_top    = (b00 + b10) >> 1;
                r_interp_bottom = (r01 + r11) >> 1;
                g_interp_bottom = (g01 + g11) >> 1;
                b_interp_bottom = (b01 + b11) >> 1;
            end else begin
                r_interp_top    = r00;
                g_interp_top    = g00;
                b_interp_top    = b00;
                r_interp_bottom = r01;
                g_interp_bottom = g01;
                b_interp_bottom = b01;
            end

            if (is_y_frac) begin
                red_interpolated   = (r_interp_top + r_interp_bottom) >> 1;
                green_interpolated = (g_interp_top + g_interp_bottom) >> 1;
                blue_interpolated  = (b_interp_top + b_interp_bottom) >> 1;
            end else begin
                red_interpolated   = r_interp_top[3:0];
                green_interpolated = g_interp_top[3:0];
                blue_interpolated  = b_interp_top[3:0];
            end
            processed_data_comb = {red_interpolated, green_interpolated, blue_interpolated};

        end else begin
            processed_data_comb = base_data;
        end
    end

    always_ff @(posedge vga_clk or posedge reset) begin
        if (reset) begin
            up_scale_data <= 0;
        end else begin
            up_scale_data <= processed_data_comb;
        end
    end
endmodule