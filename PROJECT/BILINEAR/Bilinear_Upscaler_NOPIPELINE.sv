// Bilinear_Upscaler.v
// 이 파일을 새로 만들거나, 기존 Linear_Upscaler.v를 이 내용으로 교체합니다.

module Bilinear_Upscaler (
    input  logic [11:0] p_tl,        // Top-Left pixel:    P(x, y)
    input  logic [11:0] p_tr,        // Top-Right pixel:   P(x+1, y)
    input  logic [11:0] p_bl,        // Bottom-Left pixel: P(x, y+1)
    input  logic [11:0] p_br,        // Bottom-Right pixel:P(x+1, y+1)

    input  logic        x_is_odd,    // VGA x-coordinate is odd? (sub-pixel x position)
    input  logic        y_is_odd,    // VGA y-coordinate is odd? (sub-pixel y position)

    output logic [11:0] upscaled_data
);
    // 각 채널(R, G, B)을 분리합니다.
    logic [3:0] r_tl, g_tl, b_tl;
    logic [3:0] r_tr, g_tr, b_tr;
    logic [3:0] r_bl, g_bl, b_bl;
    logic [3:0] r_br, g_br, b_br;

    assign {r_tl, g_tl, b_tl} = p_tl;
    assign {r_tr, g_tr, b_tr} = p_tr;
    assign {r_bl, g_bl, b_bl} = p_bl;
    assign {r_br, g_br, b_br} = p_br;

    // 중간 보간 값
    logic [11:0] top_interpolated, bottom_interpolated;
    
    // 1. 수평 보간
    // 윗 줄의 두 픽셀을 수평 보간 (p_tl, p_tr)
    assign top_interpolated[11:8] = ({1'b0, r_tl} + {1'b0, r_tr}) >> 1;
    assign top_interpolated[ 7:4] = ({1'b0, g_tl} + {1'b0, g_tr}) >> 1;
    assign top_interpolated[ 3:0] = ({1'b0, b_tl} + {1'b0, b_tr}) >> 1;
    
    // 아랫 줄의 두 픽셀을 수평 보간 (p_bl, p_br)
    assign bottom_interpolated[11:8] = ({1'b0, r_bl} + {1'b0, r_br}) >> 1;
    assign bottom_interpolated[ 7:4] = ({1'b0, g_bl} + {1'b0, g_br}) >> 1;
    assign bottom_interpolated[ 3:0] = ({1'b0, b_bl} + {1'b0, b_br}) >> 1;

    // 2. 최종 보간
    always_comb begin
        case ({y_is_odd, x_is_odd})
            // 2'b00: Top-Left (짝수, 짝수) -> 원본 p_tl 픽셀 사용
            2'b00: upscaled_data = p_tl; 
            
            // 2'b01: Top-Right (짝수, 홀수) -> 윗 줄 수평 보간 결과 사용
            2'b01: upscaled_data = top_interpolated;

            // 2'b10: Bottom-Left (홀수, 짝수) -> 두 줄을 수직 보간
            2'b10: begin
                logic [3:0] r_out, g_out, b_out;
                r_out = ({1'b0, r_tl} + {1'b0, r_bl}) >> 1;
                g_out = ({1'b0, g_tl} + {1'b0, g_bl}) >> 1;
                b_out = ({1'b0, b_tl} + {1'b0, b_bl}) >> 1;
                upscaled_data = {r_out, g_out, b_out};
            end

            // 2'b11: Bottom-Right (홀수, 홀수) -> 수평 보간된 두 결과를 다시 수직 보간 (4개 픽셀 평균)
            2'b11: begin
                logic [3:0] r_out, g_out, b_out;
                // (top_interpolated + bottom_interpolated) / 2
                r_out = ({1'b0, top_interpolated[11:8]} + {1'b0, bottom_interpolated[11:8]}) >> 1;
                g_out = ({1'b0, top_interpolated[ 7:4]} + {1'b0, bottom_interpolated[ 7:4]}) >> 1;
                b_out = ({1'b0, top_interpolated[ 3:0]} + {1'b0, bottom_interpolated[ 3:0]}) >> 1;
                upscaled_data = {r_out, g_out, b_out};
            end
            default: upscaled_data = 12'h000;
        endcase
    end
endmodule