`define mult_clk 5'h1
`timescale 1ns / 1ps

module exe(                         
    input              EXE_valid,   
    input      [174:0] ID_EXE_bus_r,
    output             EXE_over,    
    output     [159:0] EXE_MEM_bus, 
    

    input              clk,         
    output     [  4:0] EXE_wdest,  
    output     [ 31:0] EXE__result,
    output             EXE_load, 
    output             EXE_multiply, 
    input      [ 31:0] HI_data,
    input      [ 31:0] LO_data,
    input      [ 31:0] WB_hi_data,
    input      [ 31:0] WB_lo_data,
    input              WB_hi_write,
    input              WB_lo_write,
    input      [ 31:0] cp0r_status,
    input      [ 31:0] cp0r_cause,
    input      [ 31:0] cp0r_epc,
    input      [ 31:0] cp0r_badvaddr,
    input              MEM_mfhi,
    input              MEM_mflo,
    input              MEM_hi_write,
    input              MEM_lo_write,
    input      [ 31:0] MEM_hi_data,
    input      [ 31:0] MEM_lo_data   
);

    wire inst_jbr;
    wire multiply;            
    wire divide;
    wire mthi;             //MTHI
    wire mtlo;             //MTLO
    wire unsined_op;
    wire [11:0] alu_control;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;


    wire [4:0] mem_control;  
    wire [31:0] store_data;  
                          

    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   
    wire       break;
    wire       add_sub;
    wire       eret;
    wire       ri_ex;
    wire       rf_wen;    
    wire [4:0] rf_wdest;  
    //pc
    wire [31:0] pc;
    assign {inst_jbr,
            multiply,
            divide,
            unsined_op,
            mthi,
            mtlo,
            alu_control,
            alu_operand1,
            alu_operand2,
            mem_control,
            store_data,
            mfhi,
            mflo,
            mtc0,
            mfc0,
            cp0r_addr,
            syscall,
            break,
            add_sub,
            ri_ex,
            eret,
            rf_wen,
            rf_wdest,
            pc          } = ID_EXE_bus_r;
    assign EXE_multiply = multiply & EXE_valid;
//-----{ID->EXE}end

//-----{ALU}begin
    wire [31:0] alu_result;
    wire        ov_ex;
    wire        ov;

    alu alu_module(
        .alu_control  (alu_control ),  
        .alu_src1     (alu_operand1),  
        .alu_src2     (alu_operand2),  
        .alu_result   (alu_result  ),  
        .ov_ex        (ov)
    );
    assign ov_ex = ov & add_sub;
//-----{ALU}end

//-----{mult}begin
    // wire        mult_begin; 
    wire [65:0] product; 
    wire        mult_end;
    reg  [4:0]  times;
    wire [4:0]  times_w;
    assign times_w = times;
    always @(posedge clk)
    begin
        if(multiply & EXE_valid & mult_end == 1'b0)
        begin
            times <= times + 1'b1;
        end
        else
        begin
            times <= 1'b0;
        end
    end
    assign mult_end = (times_w == `mult_clk);

    multiplier multiplier_module (
        .CLK       (clk),
        .A          ({unsined_op ? 1'b0 : alu_operand1[31], alu_operand1}),
        .B          ({unsined_op ? 1'b0 : alu_operand2[31], alu_operand2}),
        .P          (product)
    );
//-----{mult}end

//-----{div}begin
    reg div_begin_r;
    reg div_valid;
    wire div_end;
    // reg [31: 0]s_axis_divisor_tdata;
    // reg [31: 0]s_axis_dividend_tdata;
    wire [79:0] product_div; 
    always @(posedge clk)
    begin
        if(div_begin_r == 1'b1)
        begin
            div_begin_r <= 1'b0;
            div_valid <= 1'b1;
        end
        else if(divide & EXE_valid & div_valid !== 1'b1)
        begin
            div_begin_r <= 1'b1;
            // s_axis_dividend_tdata <= alu_operand2;
            // s_axis_divisor_tdata <= alu_operand1;
        end
        else if(div_end == 1'b1)
        begin
            div_valid <= 1'b0;
        end
        // else
        // begin
        //     // div_begin_r <= 1'b0;
        //     // s_axis_dividend_tdata <= 32'b0;
        //     // s_axis_divisor_tdata <= 32'b0;
        // end
    end
    divider divider_module(
        .aclk                   (clk),
        .s_axis_divisor_tdata   ({unsined_op ? 1'b0 : alu_operand2[31], alu_operand2}),
        .s_axis_dividend_tdata  ({unsined_op ? 1'b0 : alu_operand1[31], alu_operand1}),
        .m_axis_dout_tdata      (product_div),  
        .m_axis_dout_tvalid     (div_end),
        .s_axis_divisor_tvalid  (div_begin_r),
        .s_axis_dividend_tvalid (div_begin_r)
    );
//-----{div}end

    assign EXE_over = EXE_valid & (~multiply | mult_end) & (~divide | div_end);


    wire   EXE_wen;
    assign EXE_wdest = rf_wdest & {5{EXE_valid}};
    assign EXE_wen = rf_wen & ~ov_ex;
    assign EXE_load   = mem_control[4] & EXE_valid;



    wire [31:0] exe_result;   
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    wire [31:0] cp0r_rdata;

    assign cp0r_rdata = (cp0r_addr=={5'd12,3'd0}) ? cp0r_status :
                        (cp0r_addr=={5'd13,3'd0}) ? cp0r_cause  :
                        (cp0r_addr=={5'd14,3'd0}) ? cp0r_epc : 
                        (cp0r_addr=={5'd08,3'd0}) ? cp0r_badvaddr : 32'd0;


    assign exe_result = mthi     ? alu_operand1 :
                        mtc0     ? alu_operand2 : 
                        multiply ? product[63:32] : 
                        divide   ? product_div[31: 0] : alu_result;
    assign EXE__result = (mflo & EXE_valid & MEM_lo_write)                ? (MEM_lo_data & {32{EXE_valid}}) :
                         (mflo & EXE_valid & !MEM_lo_write & WB_lo_write) ? (WB_lo_data & {32{EXE_valid}})  :
                         (mflo & EXE_valid & !MEM_lo_write & !WB_lo_write)? (LO_data & {32{EXE_valid}})     :
                         (mfhi & EXE_valid & MEM_hi_write)                ? (MEM_hi_data & {32{EXE_valid}}) :
                         (mfhi & EXE_valid & !MEM_hi_write & WB_hi_write) ? (WB_hi_data & {32{EXE_valid}})  :
                         (mfhi & EXE_valid & !MEM_hi_write & !WB_hi_write)? (HI_data & {32{EXE_valid}})     :
                         (mfc0 & EXE_valid )                              ? (cp0r_rdata&{32{EXE_valid}}) :
                         exe_result & {32{EXE_valid}};

    assign lo_result  = mtlo    ? alu_operand1   : 
                        divide  ? product_div[71:40] : product[31:0];
    assign hi_write   = multiply | mthi | divide;
    assign lo_write   = multiply | mtlo | divide;
    
    assign EXE_MEM_bus = {inst_jbr,mem_control,store_data,          
                          exe_result,                     
                          lo_result,                       
                          hi_write,lo_write,               
                          mfhi,mflo,                      
                          mtc0,mfc0,cp0r_addr,syscall,break,ov_ex,ri_ex,eret,
                          EXE_wen,rf_wdest,                
                          pc};                             //PC
//-----{EXE->MEM??}end


endmodule
