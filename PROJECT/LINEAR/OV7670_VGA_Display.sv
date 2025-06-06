`timescale 1ns / 1ps

module OV7670_VGA_Display (
    // global signals
    input  logic       clk,
    input  logic       reset,
    input  logic [4:0] rgb_sw,
    input  logic [1:0] btn,
    //input  logic       start_btn,
    // ov7670 signals
    output logic       ov7670_x_clk,
    input  logic       ov7670_pixel_clk,
    input  logic       ov7670_href,
    input  logic       ov7670_vsync,
    input  logic [7:0] ov7670_data,
    output logic       SCL,
    output logic       SDA,
    // export signals
    output logic       Hsync,
    output logic       Vsync,
    output logic [3:0] vgaRed,
    output logic [3:0] vgaGreen,
    output logic [3:0] vgaBlue
);
    logic        display_en;
    logic [ 9:0] x_coor, y_coor;
    logic        we;
    logic [16:0] wAddr, rAddr;
    logic [11:0] wData, rData;
    logic        w_rclk, oe;

    logic        VGA_SIZE;

    assign VGA_SIZE = rgb_sw[0];

    SCCB_intf U_SCCB(
        .clk(clk), 
        .reset(reset), 
        //.start_btn(start_btn),
        .SCL(SCL), 
        .SDA(SDA)
    );
    
    vga_Controller U_VGA_CONTROLLER ( 
        .clk(clk), 
        .reset(reset), 
        .Hsync(Hsync), 
        .Vsync(Vsync), 
        .display_en(display_en), 
        .x_coor(x_coor), 
        .y_coor(y_coor), 
        .pixel_clk(ov7670_x_clk), 
        .rclk(w_rclk) 
    );
    
    ov7670_controller U_OV7670_MEM( 
        .pclk(ov7670_pixel_clk), 
        .reset(reset), 
        .href(ov7670_href), 
        .vsync(ov7670_vsync), 
        .ov7670_data(ov7670_data), 
        .we(we), 
        .wAddr(wAddr), 
        .wData(wData) 
    );

    frame_buffer U_FRAME_BUFF ( 
        .wclk(ov7670_pixel_clk), 
        .we(we), 
        .wAddr(wAddr), 
        .wData(wData), 
        .rclk(w_rclk), 
        .oe(oe),        
        .rAddr(rAddr),  
        .rData(rData) 
    );
    
    VGA_Output_Processor U_VGA_OUTPUT (
        .clk(w_rclk),         
        .reset(reset),
        .vga_size_mode(VGA_SIZE),
        .display_en(display_en),
        .x_coor(x_coor),
        .y_coor(y_coor),
        .fb_rdata(rData),
        .fb_oe(oe),
        .fb_rAddr(rAddr),
        .vgaRed(vgaRed),
        .vgaGreen(vgaGreen),
        .vgaBlue(vgaBlue)
    );

endmodule