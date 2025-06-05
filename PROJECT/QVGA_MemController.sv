`timescale 1ns / 1ps

module QVGA_MemController (
    input  logic        clk,
    input  logic [ 9:0] x_coor,
    input  logic [ 8:0] y_coor,
    input  logic        display_en,
    output logic        rclk,
    output logic        de,
    output logic [16:0] rAddr,
    input  logic [11:0] rData,
    output logic [ 3:0] vgaRed,
    output logic [ 3:0] vgaGreen,
    output logic [ 3:0] vgaBlue
);
    always_comb begin 
        rclk = clk;
        de = (x_coor < 320 && y_coor < 240);
        rAddr = de ? (y_coor * 320 + x_coor) : 0;
        {vgaRed, vgaGreen, vgaBlue} = de ? {rData[11:8], rData[7:4], rData[3:0]} : 0;       
    end
endmodule