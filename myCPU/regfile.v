`timescale 1ns / 1ps

module regfile(
    input             clk,
    input             wen,
    input      [4 :0] raddr1,
    input      [4 :0] raddr2,
    input      [4 :0] waddr,
    input      [31:0] wdata,
    output     [31:0] rdata1,
    output     [31:0] rdata2,

    output [3:0]debug_wb_rf_wen,
    output [4:0]debug_wb_rf_wnum,
    output [31:0]debug_wb_rf_wdata 
    );
    reg [31:0] rf[31:0];
    assign debug_wb_rf_wen = {4{wen}};
    assign debug_wb_rf_wdata = wdata;
    assign debug_wb_rf_wnum = waddr;
     
    // three ported register file
    // read two ports combinationally
    // write third port on rising edge of clock
    // register 0 hardwired to 0
    
    always @(posedge clk)
    begin
        if (wen && waddr != 5'b0) 
        begin
            rf[waddr] <= wdata;
        end
    end
    assign rdata1 = (raddr1 == 5'b0)          ? 32'b0 : 
                    (raddr1 == waddr)&&(wen)  ? wdata :
                    rf[raddr1];
    assign rdata2 = (raddr2 == 5'b0)          ? 32'b0 : 
                    (raddr2 == waddr)&&(wen)  ? wdata :
                    rf[raddr2];
endmodule
