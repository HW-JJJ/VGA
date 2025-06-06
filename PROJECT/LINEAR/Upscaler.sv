`timescale 1ns / 1ps

module Linear_Upscaler (
    input  logic [11:0] p1_data,    // Left pixel
    input  logic [11:0] p2_data,    // Right pixel
    input  logic        x_is_odd,   // Flag if VGA x-coordinate is odd
    output logic [11:0] upscaled_data
);

    // 입력 픽셀에서 R, G, B 채널 분리
    logic [3:0] r1, g1, b1;
    logic [3:0] r2, g2, b2;

    assign {r1, g1, b1} = p1_data;
    assign {r2, g2, b2} = p2_data;

    // 보간 연산 수행
    always_comb begin
        if (x_is_odd) begin
            // 홀수 X좌표: 두 픽셀의 평균값 계산 (오버플로우 방지)
            logic [3:0] r_out, g_out, b_out;
            r_out = ({1'b0, r1} + {1'b0, r2}) >> 1;
            g_out = ({1'b0, g1} + {1'b0, g2}) >> 1;
            b_out = ({1'b0, b1} + {1'b0, b2}) >> 1;
            upscaled_data = {r_out, g_out, b_out};
        end else begin
            // 짝수 X좌표: 왼쪽 픽셀 값을 그대로 사용
            upscaled_data = p1_data;
        end
    end

endmodule