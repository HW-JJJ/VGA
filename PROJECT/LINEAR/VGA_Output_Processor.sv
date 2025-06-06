`timescale 1ns / 1ps

module VGA_Output_Processor (
    // Global Signals
    input  logic       clk,           // VGA 픽셀 클럭 (w_rclk)을 연결
    input  logic       reset,
    // Control Inputs
    input  logic       vga_size_mode, // 0: 320x240, 1: 640x480
    input  logic       display_en,
    input  logic [9:0] x_coor,
    input  logic [9:0] y_coor,

    // Data Input from Frame Buffer
    input  logic [11:0] fb_rdata,     // Frame Buffer Read Data

    // Outputs to Frame Buffer
    output logic       fb_oe,         // Frame Buffer Output Enable
    output logic [16:0] fb_rAddr,     // Frame Buffer Read Address

    // Final VGA Outputs
    output logic [3:0] vgaRed,
    output logic [3:0] vgaGreen,
    output logic [3:0] vgaBlue
);
    logic [8:0] qvga_x;
    logic [7:0] qvga_y;

    assign qvga_x = x_coor[9:1];
    assign qvga_y = y_coor[9:1]; 
                                   
    assign fb_oe = display_en;
    assign fb_rAddr = (vga_size_mode) ? (qvga_y * 320 + qvga_x) :
                                        (y_coor < 240 ? y_coor * 320 + x_coor : 0);

    logic [11:0] p1_s1, p2_s1; 
    logic [9:0]  x_coor_s1;
    logic        display_en_s1;
    logic [11:0] upscaled_data_reg;

    wire [11:0] upscaler_out; 

    Linear_Upscaler U_UPSCALER (
        .p1_data(p2_s1), // 왼쪽 픽셀
        .p2_data(p1_s1), // 오른쪽 픽셀
        .x_is_odd(x_coor_s1[0]),
        .upscaled_data(upscaler_out)
    );
                                
    always_ff @(posedge clk) begin
        if (reset) begin
            p1_s1 <= '0;
            p2_s1 <= '0;
            x_coor_s1 <= '0;
            display_en_s1 <= '0;
            upscaled_data_reg <= '0;
        end else begin
            // 스테이지 1: 프레임 버퍼 데이터와 제어 신호를 레지스터에 저장
            p1_s1 <= fb_rdata;
            p2_s1 <= p1_s1;
            
            x_coor_s1 <= x_coor;
            display_en_s1 <= display_en;

            // 최종 출력 레지스터링
            if (display_en_s1) begin
                upscaled_data_reg <= upscaler_out;
            end else begin
                upscaled_data_reg <= '0;
            end
        end
    end

    // 최종 VGA 색상 출력
    always_comb begin
        if (vga_size_mode) begin
            // 640x480 모드: 업스케일링된 데이터 사용
            vgaRed   = upscaled_data_reg[11:8];
            vgaGreen = upscaled_data_reg[7:4];
            vgaBlue  = upscaled_data_reg[3:0];
        end else begin
            // 320x240 모드: 프레임 버퍼 데이터 직접 사용 (파이프라인 지연 고려)
            if (x_coor < 320 && y_coor < 240 && display_en_s1) begin
                vgaRed   = p2_s1[11:8];
                vgaGreen = p2_s1[7:4];
                vgaBlue  = p2_s1[3:0];
            end else begin
                vgaRed   = 4'h0;
                vgaGreen = 4'h0;
                vgaBlue  = 4'h0;
            end
        end
    end

endmodule