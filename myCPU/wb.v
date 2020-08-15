`timescale 1ns / 1ps

`define EXC_ENTER_ADDR 32'hbfc00380     
                                 
module wb(                      
    input          WB_valid,    
    input  [156:0] MEM_WB_bus_r, 
    output         rf_wen,      
    output [  4:0] rf_wdest,     
    output [ 31:0] rf_wdata,     
    output         WB_over,      
    input              inst_addr_ok ,


    input             clk,       
    input             resetn,     
    output [ 32:0] exc_bus,      
//     output [  4:0] WB_wdest,    
    output         cancel,      
                                  

    output [ 31:0] WB_pc,
    input  [  5:0] ext_int,
    input          WB_allow_in,
    input          MEM_over,

    output [ 31:0] HI_data,
    output [ 31:0] LO_data,
    output [ 31:0] WB_hi_data,
    output [ 31:0] WB_lo_data,
    output         WB_hi_write,
    output         WB_lo_write,
    //output         WB_mfc0,
    //output         WB_mtc0,
    output [31:0] cp0r_status,
    output [31:0] cp0r_cause,
    output [31:0] cp0r_epc,
    output [31:0] cp0r_badvaddr 
);
    wire inst_jbr;
    reg ds;
    always @(posedge clk)
    begin
        if(MEM_over && WB_allow_in && inst_jbr)
        begin
            ds <= 1'b1;
        end
        else if(MEM_over && WB_allow_in)
        begin
            ds <= 1'b0;
        end
    end

    wire [31:0] mem_result;

    wire [31:0] lo_result;
    
    wire wen;
    wire [4:0] wdest;
    
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;    
    wire       break;
    wire       ov_ex;
    wire       ades_ex;
    wire       adel_ex;
    wire       ri_ex;   
    wire       eret;
    wire [31:0]dm_addr;
    //pc
    wire [31:0] pc;    
    assign {inst_jbr,
            wen,
            wdest,
            mem_result,
            lo_result,
            WB_hi_write,
            WB_lo_write,
            mfhi,
            mflo,
            mtc0,
            mfc0,
            cp0r_addr,
            syscall,
            break,
            ov_ex,
            adel_ex,
            ades_ex,
            ri_ex,
            eret,
            dm_addr,
            pc} = MEM_WB_bus_r;

    reg [31:0] hi;
    reg [31:0] lo;
    
    always @(posedge clk)
    begin
        if(!resetn)
        begin
            hi <= 32'b0;
        end
        else if (WB_hi_write)
        begin
            hi <= mem_result;
        end
    end

    always @(posedge clk)
    begin
        if(!resetn)
        begin
            lo <= 32'b0;
        end
        else if (WB_lo_write)
        begin
            lo <= lo_result;
        end
    end

    assign WB_hi_data    = mem_result;
    assign WB_lo_data    = lo_result;

   wire [31:0] cp0r_count;
   wire [31:0] cp0r_compare;

   wire status_wen;
   //wire cause_wen;
   wire epc_wen;
   // count
   wire count_wen;
   wire compare_wen;
   wire cause_wen;
   assign cause_wen = mtc0 & (cp0r_addr=={5'd13,3'd0}) & WB_valid;
   assign status_wen = mtc0 & (cp0r_addr=={5'd12,3'd0}) & WB_valid;
   assign epc_wen    = mtc0 & (cp0r_addr=={5'd14,3'd0}) & WB_valid;
   assign count_wen  = mtc0 & (cp0r_addr=={5'd9 ,3'd0}) & WB_valid;
   assign compare_wen  = mtc0 & (cp0r_addr=={5'd11 ,3'd0}) & WB_valid;

   wire [31:0] cp0r_rdata;
   assign cp0r_rdata = (cp0r_addr=={5'd12,3'd0}) ? cp0r_status :
                       (cp0r_addr=={5'd13,3'd0}) ? cp0r_cause  :
                       (cp0r_addr=={5'd14,3'd0}) ? cp0r_epc : 
                       (cp0r_addr=={5'd08,3'd0}) ? cp0r_badvaddr : 
                       (cp0r_addr=={5'd09,3'd0}) ? cp0r_count : 32'd0;
    wire int0_ex;
    assign int0_ex = cp0r_status[0] & ~cp0r_status[1] & cp0r_status[8] & cp0r_cause[8]; 
   
    wire int1_ex;
    assign int1_ex = cp0r_status[0] & ~cp0r_status[1] & cp0r_status[9] & cp0r_cause[9];
   
    wire int2_ex;
    assign int2_ex = cp0r_status[0] & ~cp0r_status[1] & cp0r_status[10] & cp0r_cause[10];
   
    wire int3_ex;
    assign int3_ex = cp0r_status[0] & ~cp0r_status[1] & cp0r_status[11] & cp0r_cause[11];
   
    wire int4_ex;
    assign int4_ex = cp0r_status[0] & ~cp0r_status[1] & cp0r_status[12] & cp0r_cause[12];
   
    wire int5_ex;
    assign int5_ex = cp0r_status[0] & ~cp0r_status[1] & cp0r_status[13] & cp0r_cause[13];
   
    wire int6_ex;
    assign int6_ex = cp0r_status[0] & ~cp0r_status[1] & cp0r_status[14] & cp0r_cause[14];
   
    wire int7_ex;
    assign int7_ex = cp0r_status[0] & ~cp0r_status[1] & cp0r_status[15] & cp0r_cause[15];
   
    wire int_ex;
    assign int_ex = int0_ex | int1_ex | int2_ex | int3_ex | int4_ex | int5_ex | int6_ex | int7_ex;

   reg [31:0]badvaddr_r;
   assign cp0r_badvaddr = badvaddr_r;
   always @(posedge clk)
   begin
       if(adel_ex | ades_ex)
       begin
           badvaddr_r <= dm_addr;
       end
       else if(|pc[1:0] & WB_valid)
       begin
           badvaddr_r <= pc;
       end
   end

    wire        exc_valid;
   reg [31:0]status_exl_r;
   assign cp0r_status = status_exl_r;
   always @(posedge clk)
   begin
       if (!resetn || eret)
       begin
           status_exl_r <= {9'd0, 1'd1, 20'd0 ,1'b0, 1'b0};
       end
       else if (syscall | break | ov_ex | adel_ex | ades_ex | ri_ex | (|pc[1:0]))
       begin
           status_exl_r <= {9'd0, 1'd1, 20'd0 ,1'b1,1'b0};
       end
       else if(int_ex & exc_valid)
       begin
           status_exl_r[1] <= 1'b1;
       end
       else if (status_wen)
       begin
           status_exl_r <= mem_result;
       end
   end
   
   reg [31:0] cause_exc_r;
   assign cp0r_cause = cause_exc_r;
   wire bd;
   assign bd = ds;
   always @(posedge clk)
   begin      
       if (syscall)
       begin
           cause_exc_r <= {bd,cause_exc_r[30],14'd0,ext_int[5],ext_int[4:0],3'd0,5'd8,2'd0};
       end
       else if(break)
       begin
           cause_exc_r <= {bd,cause_exc_r[30],14'd0,ext_int[5],ext_int[4:0],3'd0,5'd9,2'd0};
       end
       else if(ov_ex)
       begin
           cause_exc_r <= {bd,cause_exc_r[30],14'd0,ext_int[5],ext_int[4:0],3'd0,5'hc,2'd0};
       end
       else if(ades_ex)
       begin
           cause_exc_r <= {bd,cause_exc_r[30],14'd0,ext_int[5],ext_int[4:0],3'd0,5'd5,2'd0};
       end
       else if(adel_ex | ((|pc[1:0]) & WB_valid))
       begin
           cause_exc_r <= {bd,cause_exc_r[30],14'd0,ext_int[5],ext_int[4:0],3'd0,5'd4,2'd0};
       end
       else if(int_ex)
       begin
           cause_exc_r[6:2] <= 5'd0;
       end
       else if(ri_ex)
       begin
           cause_exc_r <= {bd,cause_exc_r[30],14'd0,ext_int[5],ext_int[4:0],3'd0,5'ha,2'd0};
       end
       else if(cp0r_count == cp0r_compare)
       begin
           cause_exc_r[30] <= 1'b1;
           cause_exc_r[15] <= 1'b1;
       end
       else if(compare_wen)
       begin
           cause_exc_r[30] <= 1'b0;
       end
       else if(cause_wen)
       begin
           cause_exc_r <= mem_result;
       end
       else
       begin
           cause_exc_r[15:8] <= {ext_int[5],ext_int[4:0],2'd0};
       end
   end
   
   reg [31:0] epc_r;
   assign cp0r_epc = epc_r;
   always @(posedge clk)
   begin
       if ((syscall | break | ov_ex | ades_ex | adel_ex | ri_ex | int_ex | (|pc[1:0] & WB_valid)) & ~bd)
       begin
           epc_r <= pc;
       end
       else if ((syscall | break | ov_ex | ades_ex | adel_ex | ri_ex | int_ex | (|pc[1:0] & WB_valid)) & bd)
       begin
           epc_r <= {pc[31:2] - 1'b1, pc[1:0]};
       end
       else if (epc_wen)
       begin
           epc_r <= mem_result;
       end
   end

    reg [31:0]count_r;
    assign cp0r_count = count_r;
    always @(posedge clk)
    begin
        if(count_wen)
        begin
            count_r <= mem_result;
        end
        else
        begin
            count_r <= count_r + 1'd1;
        end
    end

   reg [31:0]compare_r;
   assign cp0r_compare = compare_r;
   always @(posedge clk)
   begin
       if(compare_wen)
       begin
           compare_r <= mem_result;
       end
   end
   
   assign cancel = (syscall | eret | break | ov_ex | adel_ex | ades_ex | ri_ex | int_ex | (|pc[1:0])) & WB_over;

    assign WB_over = WB_valid;

    assign rf_wen   = wen & WB_over;
    assign rf_wdest = wdest;
    assign rf_wdata = mfhi ? hi :
                      mflo ? lo :
                      mfc0 ? cp0r_rdata : mem_result;

    wire [31:0] exc_pc;
    reg exc_valid_;
    always @(posedge clk) 
    begin
        if(inst_addr_ok)
        begin
            exc_valid_ <= 1'b0;
        end
        else if(WB_valid)
        begin
            exc_valid_ <= exc_valid;
        end
    end    

    assign exc_valid = WB_valid ? (syscall | eret | break | ov_ex | adel_ex | ades_ex | ri_ex | int_ex | (|pc[1:0])) : exc_valid_;

    assign exc_pc = syscall | break | ov_ex | ades_ex | adel_ex | ri_ex | int_ex | (|pc[1:0]) ? `EXC_ENTER_ADDR : cp0r_epc;
    // assign exc_pc = cp0r_epc;
    
    assign exc_bus = {exc_valid,exc_pc};

    assign WB_pc = pc;
    assign HI_data = hi;
    assign LO_data = lo;

endmodule

