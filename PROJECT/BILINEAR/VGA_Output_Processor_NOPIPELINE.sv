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
    // --- 주소 및 OE 신호 생성 ---
    logic [8:0] qvga_x;
    logic [8:0] qvga_y; // y_coor는 최대 479이므로 9비트면 충분합니다.

    // 640x480 -> 320x240 매핑을 위한 좌표 계산 (2로 나누기)
    assign qvga_x = x_coor[9:1];
    assign qvga_y = y_coor[9:1]; 
                                   
    assign fb_oe = display_en;
    // vga_size_mode에 따라 프레임 버퍼 읽기 주소 계산
    // Upscaling 모드에서는 항상 현재 y좌표에 해당하는 QVGA 라인을 읽습니다.
    assign fb_rAddr = (vga_size_mode) ? (qvga_y * 320 + qvga_x) :
                                        (y_coor < 240 ? y_coor * 320 + x_coor : 0);

    // --- Bilinear Interpolation을 위한 라인 버퍼 및 파이프라인 ---

    // 라인 버퍼: QVGA 한 줄(320 픽셀)을 저장
    logic [11:0] line_buffer [0:319];
    
    // 파이프라인 레지스터
    // S1: 프레임버퍼와 라인버퍼에서 읽은 데이터를 받는 첫 단계
    logic [11:0] p_current_row_s1; // 현재 QVGA 라인(y)에서 온 픽셀
    logic [11:0] p_prev_row_s1;    // 이전 QVGA 라인(y-1)에서 온 픽셀 (라인 버퍼 출력)
    
    // S2: S1의 데이터를 한 클럭 지연시켜 수평 픽셀 2개를 확보
    logic [11:0] p_current_row_s2; // p_current_row_s1의 지연된 값
    logic [11:0] p_prev_row_s2;    // p_prev_row_s1의 지연된 값

    // 제어 신호 파이프라인
    logic [9:0]  x_coor_s1, y_coor_s1;
    logic [9:0]  x_coor_s2, y_coor_s2;
    logic        display_en_s1, display_en_s2;
    logic [11:0] upscaled_data_reg;

    wire [11:0] upscaler_out; 

    // Bilinear Upscaler 인스턴스
    Bilinear_Upscaler U_UPSCALER (
        .p_tl(p_prev_row_s2),       // P(x-1, y-1)
        .p_tr(p_prev_row_s1),       // P(x,   y-1)
        .p_bl(p_current_row_s2),    // P(x-1, y)
        .p_br(p_current_row_s1),    // P(x,   y)
        .x_is_odd(x_coor_s2[0]),
        .y_is_odd(y_coor_s2[0]),
        .upscaled_data(upscaler_out)
    );
                                
    always_ff @(posedge clk) begin
        if (reset) begin
            p_current_row_s1 <= '0;
            p_prev_row_s1    <= '0;
            p_current_row_s2 <= '0;
            p_prev_row_s2    <= '0;
            x_coor_s1 <= '0; y_coor_s1 <= '0;
            x_coor_s2 <= '0; y_coor_s2 <= '0;
            display_en_s1 <= '0; display_en_s2 <= '0;
            upscaled_data_reg <= '0;
        end else begin
            // --- 라인 버퍼 관리 ---
            // 프레임버퍼에서 읽은 데이터(현재 라인 픽셀)를 라인 버퍼에 쓴다.
            // 이렇게 하면 다음 라인을 처리할 때 이 데이터가 "이전 라인" 데이터가 된다.
            if (display_en) begin
                line_buffer[qvga_x] <= fb_rdata;
            end

            // --- 파이프라인 스테이지 1: 데이터 가져오기 ---
            // BRAM 읽기 레이턴시가 1클럭이므로, fb_rdata는 현재 rAddr에 대한 결과.
            p_current_row_s1 <= fb_rdata; 
            // 라인 버퍼 읽기는 조합 논리이므로, 현재 qvga_x에 대한 결과를 바로 가져옴.
            p_prev_row_s1    <= line_buffer[qvga_x];

            // --- 파이프라인 스테이지 2: 수평 지연 ---
            p_current_row_s2 <= p_current_row_s1;
            p_prev_row_s2    <= p_prev_row_s1;

            // --- 제어 신호도 데이터와 함께 지연 ---
            display_en_s1 <= display_en;
            x_coor_s1     <= x_coor;
            y_coor_s1     <= y_coor;
            
            display_en_s2 <= display_en_s1;
            x_coor_s2     <= x_coor_s1;
            y_coor_s2     <= y_coor_s1;

            // --- 최종 출력 레지스터링 ---
            // Bilinear_Upscaler는 조합 논리. S2 레지스터 출력이 안정되면 바로 upscaler_out이 나옴.
            if (display_en_s2) begin
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
            // 파이프라인이 2단으로 늘어났으므로, 2클럭 전의 픽셀(p_current_row_s2)을 사용
            if (x_coor < 320 && y_coor < 240 && display_en_s2) begin
                vgaRed   = p_current_row_s2[11:8];
                vgaGreen = p_current_row_s2[7:4];
                vgaBlue  = p_current_row_s2[3:0];
            end 
            else begin
                vgaRed   = 4'h0;
                vgaGreen = 4'h0;
                vgaBlue  = 4'h0;
            end
        end
    end
endmodule