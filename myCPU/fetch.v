`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: fetch.v
//   > 描述  :五级流水CPU的取指模块
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
`define STARTADDR 32'Hbfc00000   // 程序起始地址为0xbfc00000
module fetch(                    // 取指级
    input             clk,       // 时钟
    input             resetn,    // 复位信号，低电平有效
    input             IF_valid,  // 取指级有效信号
    input             IF_allow_in,// 取下一条指令，用来锁存PC值
    //input      [31:0] inst,      // inst_rom取出的指令
    input      [32:0] jbr_bus,   // 跳转总线
    //output     [31:0] inst_addr, // 发往inst_rom的取指地址
    output            IF_over,   // IF模块执行完成
    output     [63:0] IF_ID_bus, // IF->ID总线
    
    //5级流水新增接口
    input      [32:0] exc_bus,   // Exception pc总线
    input             EXE_multiply,//
    inout             MEM_over,  // 
    input             MEM_valid_r, 
    input            load_relate1,// 是否发生load相关（ID-EXE）
    input            load_relate2,// 是否发生load相关 (ID-MEM)
    input            WB_valid, 

    //类SRAM新增接口
    output         inst_req     ,
    output         inst_wr      ,
    output  [1 :0] inst_size    ,
    output  [31:0] inst_addr    ,
    output  [31:0] inst_wdata   ,
    input   [31:0] inst_rdata   ,
    input          inst_addr_ok ,
    input          inst_data_ok   //
);

//-----{连线赋值}begin
    //读取的指令都为4字节
    assign inst_size = 2'b10;
    //这里默认没有指令要向内存写入新的指令，因此写使能写数据都为0
    assign inst_wr = 1'b0;
    assign inst_wdata = 32'H00000000;
//-----{连线赋值}begin

//-----{类SRAM的req信号}begin
    reg inst_req_;
    
    assign inst_req = (!IF_valid)                 ?    1'b0    :
                      inst_req_ ;//& IF_allow_in
    
    always @(posedge clk)    // PC程序计数器
    begin
        if(IF_over | (resetn & !IF_valid))
        begin
            inst_req_ <= 1'b1;
        end
        else if(IF_valid && !inst_addr_ok && inst_data_ok && exc_valid)
        begin
            inst_req_ <= 1'b1;
        end
        else if(inst_addr_ok)// & IF_allow_in
        begin
            inst_req_ <= 1'b0;
        end
    end
//-----{类SRAM的req信号}end

//-----{程序计数器PC}begin
    //reg [31:0] next_pc;
    wire [31:0] pre_pc_target;
    wire [31:0] pre_pc;
    reg  [31:0] pre_pc_;
    wire [31:0] seq_pc;
    wire  [31:0] pc;
    reg  [31:0] pc_;
    
    //跳转pc
    wire        jbr_taken;
    wire [31:0] jbr_target;
    assign {jbr_taken, jbr_target} = jbr_bus;  // 跳转总线传是否跳转和目标地址
    
    //Exception PC
    wire        exc_valid;
    wire [31:0] exc_pc;
    assign {exc_valid,exc_pc} = exc_bus;
    
    //pc+4
    assign seq_pc[31:2]    = pre_pc[31:2] + 1'b1;  // 下一指令地址：PC=PC+4
    assign seq_pc[1:0]     = pre_pc[1:0];

    // 新指令：若有Exception,则PC为Exceptio入口地址
    //         若指令跳转，则PC为跳转地址；否则为pc+4
    //assign next_pc = exc_valid ? exc_pc : jbr_taken ? jbr_target : seq_pc;

    //wire inst_valid;//如果当前pc和pre_pc值相同，则inst无效
    wire IF_valid_;
    assign IF_valid_ = exc_valid    ? 1'b1 :
                       load_relate1 ? 1'b0 :
                       load_relate2 ? 1'b0 :
                       IF_valid;
    //assign inst_valid = !(pc == pre_pc);
    /*
    assign pc = (!resetn)   ?   `STARTADDR    :  pc_ ;
    assign pre_pc = (!resetn)                       ?   `STARTADDR        :
                    (EXE_multiply & !IF_allow_in)   ?   pre_pc_ - 3'b100  :
                    pre_pc_ ;
    */
    assign pc = (!resetn)   ?   `STARTADDR    :
                pc_ ;
    assign pre_pc = (!resetn)   ?   `STARTADDR    :
                    (EXE_multiply&& !IF_allow_in && IF_valid_ && inst_req)   ?   pre_pc_ - 3'b100  :
                    pre_pc_ ;

    reg IF_over_1;
    always @(posedge clk) 
    begin
        IF_over_1 <= IF_over;
    end
    reg IF_valid_1;
    always @(posedge clk) 
    begin
        IF_valid_1 <= !IF_valid;
    end

    always @(posedge clk)    // PC程序计数器
    begin
        if (!resetn)
            begin
                pc_ = `STARTADDR; // 复位，取   程序起始地址
                pre_pc_ = `STARTADDR;
            end
        else if(IF_allow_in && exc_valid && IF_valid_&& !inst_addr_ok)
            begin
                if(WB_valid)
                begin
                    pc_ = exc_pc;
                    pre_pc_ = exc_pc;
                end
            end
        else if(IF_allow_in && jbr_taken && IF_valid_&& inst_addr_ok)
            begin
                if(inst_addr_ok)
                begin
                    pc_ = pre_pc_;
                    pre_pc_ = jbr_target;
                end
            end
        else if(IF_allow_in && IF_valid_ && (inst_req && inst_addr_ok ))
            begin
                if(exc_valid)
                begin
                    pre_pc_ = seq_pc;
                end
                else
                begin
                    pc_ = pre_pc_;
                    pre_pc_ = seq_pc; 
                end
            end
    end
//-----{程序计数器PC}end

//-----{发往inst_rom的取指地址}begin
    assign inst_addr = (load_relate1 | load_relate2 | !(MEM_over | IF_allow_in)) ? pc : pre_pc;
//-----{发往inst_rom的取指地址}end

//-----{IF执行完成}begin
    reg IF_over_;
    reg jbr_taken_1;
    reg jbr_taken_2;

    always @(posedge clk)
    begin
        jbr_taken_2 = jbr_taken_1;
        jbr_taken_1 = jbr_taken;
    end   

    always @(posedge clk)
    begin
        if(!resetn)
        begin
            IF_over_ <= 1'b0;   
        end

        else if(load_relate2)
        begin
            IF_over_ <= 1'b1;
        end
        else
        begin
            IF_over_ <= IF_valid_;
        end
    end

    assign IF_over = (load_relate1 | load_relate2) ?  (IF_valid_ & inst_data_ok) : (IF_over_ & !(jbr_taken_2 & MEM_valid_r)& inst_data_ok & !exc_valid);

//-----{IF执行完成}end


//-----{IF->ID总线}begin
    assign IF_ID_bus = {pc, inst_rdata};  // 取指级有效时，锁存PC和指令
//-----{IF->ID总线}end
endmodule