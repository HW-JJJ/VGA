`timescale 1ns / 1ps

module vga_Controller (
    input  logic       clk,
    input  logic       reset,
    output logic       Hsync,
    output logic       Vsync,
    output logic       display_en,
    output logic [9:0] x_coor,
    output logic [9:0] y_coor,
    output logic       pixel_clk,
    output logic       rclk
);
    logic [9:0] h_counter, v_counter;

    assign rclk = clk;

    clock_div #(.FCOUNT(4)) U_PIXEL_CLOCK_GENERATOR (
        .clk(clk),
        .reset(reset),
        .o_clk(pixel_clk)
    );

    pixel_counter_600x480 U_PIXEL_COUNTER_600x400 (.*);
    vga_decoder U_vga_decoder (.*);
endmodule

module clock_div #(
    parameter FCOUNT = 4
) (
    input  logic clk,
    input  logic reset,
    output logic o_clk
);

    logic [31:0] counter;

    always_ff @(posedge clk or posedge reset) begin : Pixel_clock_generator
        if (reset) begin
            counter <= 0;
            o_clk   <= 0;
        end else begin
            // if (counter == (FCOUNT / 2) - 1) begin
            if (counter == FCOUNT - 1) begin
                // o_clk <= ~o_clk;
                o_clk   <= 1;
                counter <= 0;
            end else begin
                o_clk   <= 0;
                counter <= counter + 1;
            end
        end
    end
endmodule

module pixel_counter_600x480 (
    input  logic       pixel_clk,
    input  logic       reset,
    output logic [9:0] h_counter,
    output logic [9:0] v_counter
);

    localparam H_MAX = 800, V_MAX = 525;

    always_ff @(negedge pixel_clk or posedge reset) begin : Horizontal_counter
        if (reset) begin
            h_counter <= 0;
        end else begin
            if (h_counter == H_MAX - 1) begin  // 640을 위해 800 count
                h_counter <= 0;
            end else begin
                h_counter <= h_counter + 1;
            end
        end
    end

    always_ff @(posedge pixel_clk or posedge reset) begin : Vertical_counter
        if (reset) begin
            v_counter <= 0;
        end else begin
            if (h_counter == H_MAX - 1) begin  // 480을 위해 525 count
                if (v_counter == V_MAX - 1) begin
                    v_counter <= 0;
                end else begin
                    v_counter <= v_counter + 1;
                end
            end
        end
    end
endmodule

module vga_decoder (
    input  logic [9:0] h_counter,
    input  logic [9:0] v_counter,

    output logic       Hsync,
    output logic       Vsync,

    output logic       display_en,
    output logic [9:0] x_coor,
    output logic [9:0] y_coor
);
    localparam H_Visible_area = 640;
    localparam H_Front_porch = 16;
    localparam HSync_pulse = 96;
    localparam H_Back_porch = 48;
    localparam H_Whole_line = 800;

    localparam V_Visible_area = 480;
    localparam V_Front_porch = 10;
    localparam VSync_pulse = 2;
    localparam V_Back_porch = 33;
    localparam V_Whole_frame = 525;

    always_comb begin : outport_condition
        Hsync = ~((h_counter >= (H_Visible_area + H_Front_porch)) &&
                 (h_counter < (H_Visible_area + H_Front_porch + HSync_pulse)));

        Vsync = ~((v_counter >= (V_Visible_area + V_Front_porch)) &&
                 (v_counter < (V_Visible_area + V_Front_porch + VSync_pulse)));

        display_en = ((h_counter < H_Visible_area) && (v_counter < V_Visible_area));
        x_coor = h_counter;
        y_coor = v_counter;
    end
endmodule