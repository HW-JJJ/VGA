`timescale 1ns / 1ps

module ov7670_controller (
    input  logic        pclk,
    input  logic        reset,
    input  logic        href,
    input  logic        vsync,
    input  logic [ 7:0] ov7670_data,
    output logic        we,
    output logic [16:0] wAddr,
    output logic [11:0] wData
);

    logic [ 9:0] h_counter;
    logic [ 7:0] v_counter;
    logic [11:0] temp_cam_data;

    assign wAddr = v_counter * 320 + h_counter[9:1];
    assign wData = temp_cam_data;

    always_ff @(posedge pclk, posedge reset) begin
        if (reset) begin
            temp_cam_data <= 0;
            h_counter     <= 0;
            we            <= 1'b0;
        end else begin
            if (href == 1'b0) begin
                h_counter <= 0;
                we        <= 1'b0;
            end else begin
                h_counter <= h_counter + 1;
                if (h_counter[0] == 1'b0) begin  
                    temp_cam_data[11:8] <= ov7670_data[7:4];
                    temp_cam_data[7:5]  <= ov7670_data[2:0];
                    we                  <= 1'b0;
                end else begin
                    temp_cam_data[4]   <= ov7670_data[7];
                    temp_cam_data[3:0] <= ov7670_data[4:1];
                    we                 <= 1'b1;
                end
            end
        end
    end

    always_ff @(posedge pclk, posedge reset) begin
        if (reset) begin
            v_counter <= 0;
        end else begin
            if (vsync == 1'b0) begin
                if (h_counter == 640 - 1) begin
                    v_counter <= v_counter + 1;
                end
            end else begin
                v_counter <= 0;
            end
        end
    end
endmodule