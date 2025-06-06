module VGA_Output_Processor (
    // 포트는 동일
    input  logic        clk, 
    input  logic        reset, 
    input  logic        vga_size_mode,
    input  logic        display_en, 
    input  logic [ 9:0] x_coor, 
    input  logic [ 9:0] y_coor,
    input  logic [11:0] fb_rdata, 
    output logic        fb_oe, 
    output logic [16:0] fb_rAddr,
    output logic [ 3:0] vgaRed, 
    output logic [ 3:0] vgaGreen, 
    output logic [ 3:0] vgaBlue
);
    logic [8:0] qvga_x, qvga_y;

    assign qvga_x = x_coor[9:1];
    assign qvga_y = y_coor[9:1];
    assign fb_oe = display_en;
    assign fb_rAddr = (vga_size_mode) ? (qvga_y * 320 + qvga_x) :
                                        (y_coor < 240 ? y_coor * 320 + x_coor : 0);

    // 라인 버퍼 
    logic [11:0] line_buffer [0:319];

    // QVGA 좌표
    logic [11:0] current_row_pixel; // 현재 줄(y) 픽셀 (From Frame Buffer)
    logic [11:0] prev_row_pixel;    // 이전 줄(y-1) 픽셀 (From Line Buffer)

    // 1클럭 지연시켜 이전 QVGA 좌표(x-1, y)의 픽셀들을 확보
    logic [11:0] current_row_pixel_s2;
    logic [11:0] prev_row_pixel_s2;

    // 제어 신호 파이프라인
    logic display_en_s1, display_en_s2;
    logic [9:0] x_coor_s1, y_coor_s1, x_coor_s2, y_coor_s2;
    logic [11:0] upscaled_data_reg;
    wire  [11:0] upscaler_out; 

    Bilinear_Upscaler U_UPSCALER (
        .p_tl(prev_row_pixel_s2),    // P(x-1, y-1)
        .p_tr(prev_row_pixel),       // P(x,   y-1)
        .p_bl(current_row_pixel_s2), // P(x-1, y)
        .p_br(current_row_pixel),    // P(x,   y)
        .x_is_odd(x_coor_s2[0]),
        .y_is_odd(y_coor_s2[0]),
        .upscaled_data(upscaler_out)
    );
                                
    always_ff @(posedge clk) begin
        if (reset) begin
            current_row_pixel <= '0; prev_row_pixel <= '0;
            current_row_pixel_s2 <= '0; prev_row_pixel_s2 <= '0;
            x_coor_s1 <= '0; y_coor_s1 <= '0; x_coor_s2 <= '0; y_coor_s2 <= '0;
            display_en_s1 <= '0; display_en_s2 <= '0;
            upscaled_data_reg <= '0;
        end else begin
            // --- 라인 버퍼 쓰기 ---
            if (display_en) begin
                line_buffer[qvga_x] <= fb_rdata;
            end

            // --- 파이프라인 S1: 현재 X 좌표의 픽셀들 읽기 ---
            current_row_pixel <= fb_rdata;           // 현재 줄(y)의 픽셀 P(x,y)
            prev_row_pixel    <= line_buffer[qvga_x]; // 이전 줄(y-1)의 픽셀 P(x,y-1)

            // --- 파이프라인 S2: 이전 X 좌표의 픽셀들을 위해 S1 값 지연 ---
            current_row_pixel_s2 <= current_row_pixel; // 1클럭 전의 P(x,y) -> 즉, 현재의 P(x-1, y)
            prev_row_pixel_s2    <= prev_row_pixel;    // 1클럭 전의 P(x,y-1) -> 즉, 현재의 P(x-1, y-1)

            // --- 제어 신호 지연 ---
            display_en_s1 <= display_en; x_coor_s1 <= x_coor; y_coor_s1 <= y_coor;
            display_en_s2 <= display_en_s1; x_coor_s2 <= x_coor_s1; y_coor_s2 <= y_coor_s1;

            // --- 최종 출력 레지스터링 ---
            if (display_en_s2) begin
                upscaled_data_reg <= upscaler_out;
            end else begin
                upscaled_data_reg <= '0;
            end
        end
    end

    always_comb begin
        if (vga_size_mode) begin // 640x480 VGA
            vgaRed   = upscaled_data_reg[11:8];
            vgaGreen = upscaled_data_reg[7:4];
            vgaBlue  = upscaled_data_reg[3:0];
        end 
        else begin // 320x240 QVGA
            if (x_coor < 320 && y_coor < 240 && display_en_s2) begin
                vgaRed = current_row_pixel_s2[11:8]; 
                vgaGreen = current_row_pixel_s2[7:4]; 
                vgaBlue = current_row_pixel_s2[3:0];
            end else begin
                vgaRed = 4'h0; 
                vgaGreen = 4'h0; 
                vgaBlue = 4'h0;
            end
        end
    end
endmodule