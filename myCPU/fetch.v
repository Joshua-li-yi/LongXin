`timescale 1ns / 1ps
//*************************************************************************
//   > �ļ���: fetch.v
//   > ����  :�弶��ˮCPU��ȡָģ��
//   > ����  : LOONGSON
//   > ����  : 2016-04-14
//*************************************************************************
`define STARTADDR 32'Hbfc00000   // ������ʼ��ַΪ0xbfc00000
module fetch(                    // ȡָ��
    input             clk,       // ʱ��
    input             resetn,    // ��λ�źţ��͵�ƽ��Ч
    input             IF_valid,  // ȡָ����Ч�ź�
    input             IF_allow_in,// ȡ��һ��ָ���������PCֵ
    //input      [31:0] inst,      // inst_romȡ����ָ��
    input      [32:0] jbr_bus,   // ��ת����
    //output     [31:0] inst_addr, // ����inst_rom��ȡָ��ַ
    output            IF_over,   // IFģ��ִ�����
    output     [63:0] IF_ID_bus, // IF->ID����
    
    //5����ˮ�����ӿ�
    input      [32:0] exc_bus,   // Exception pc����
    input             EXE_multiply,//
    inout             MEM_over,  // 
    input             MEM_valid_r, 
    input            load_relate1,// �Ƿ���load��أ�ID-EXE��
    input            load_relate2,// �Ƿ���load��� (ID-MEM)
    input            WB_valid, 

    //��SRAM�����ӿ�
    output         inst_req     ,
    output         inst_wr      ,
    output  [1 :0] inst_size    ,
    output  [31:0] inst_addr    ,
    output  [31:0] inst_wdata   ,
    input   [31:0] inst_rdata   ,
    input          inst_addr_ok ,
    input          inst_data_ok   //
);

//-----{���߸�ֵ}begin
    //��ȡ��ָ�Ϊ4�ֽ�
    assign inst_size = 2'b10;
    //����Ĭ��û��ָ��Ҫ���ڴ�д���µ�ָ����дʹ��д���ݶ�Ϊ0
    assign inst_wr = 1'b0;
    assign inst_wdata = 32'H00000000;
//-----{���߸�ֵ}begin

//-----{��SRAM��req�ź�}begin
    reg inst_req_;
    
    assign inst_req = (!IF_valid)                 ?    1'b0    :
                      inst_req_ ;//& IF_allow_in
    
    always @(posedge clk)    // PC���������
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
//-----{��SRAM��req�ź�}end

//-----{���������PC}begin
    //reg [31:0] next_pc;
    wire [31:0] pre_pc_target;
    wire [31:0] pre_pc;
    reg  [31:0] pre_pc_;
    wire [31:0] seq_pc;
    wire  [31:0] pc;
    reg  [31:0] pc_;
    
    //��תpc
    wire        jbr_taken;
    wire [31:0] jbr_target;
    assign {jbr_taken, jbr_target} = jbr_bus;  // ��ת���ߴ��Ƿ���ת��Ŀ���ַ
    
    //Exception PC
    wire        exc_valid;
    wire [31:0] exc_pc;
    assign {exc_valid,exc_pc} = exc_bus;
    
    //pc+4
    assign seq_pc[31:2]    = pre_pc[31:2] + 1'b1;  // ��һָ���ַ��PC=PC+4
    assign seq_pc[1:0]     = pre_pc[1:0];

    // ��ָ�����Exception,��PCΪExceptio��ڵ�ַ
    //         ��ָ����ת����PCΪ��ת��ַ������Ϊpc+4
    //assign next_pc = exc_valid ? exc_pc : jbr_taken ? jbr_target : seq_pc;

    //wire inst_valid;//�����ǰpc��pre_pcֵ��ͬ����inst��Ч
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

    always @(posedge clk)    // PC���������
    begin
        if (!resetn)
            begin
                pc_ = `STARTADDR; // ��λ��ȡ   ������ʼ��ַ
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
//-----{���������PC}end

//-----{����inst_rom��ȡָ��ַ}begin
    assign inst_addr = (load_relate1 | load_relate2 | !(MEM_over | IF_allow_in)) ? pc : pre_pc;
//-----{����inst_rom��ȡָ��ַ}end

//-----{IFִ�����}begin
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

//-----{IFִ�����}end


//-----{IF->ID����}begin
    assign IF_ID_bus = {pc, inst_rdata};  // ȡָ����Чʱ������PC��ָ��
//-----{IF->ID����}end
endmodule