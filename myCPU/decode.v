`timescale 1ns / 1ps

module decode(                      
    input              clk,         
    input              ID_valid,    
    input              ID_allow_in,
    input      [ 63:0] IF_ID_bus_r, 
    input      [ 31:0] rs_value,    
    input      [ 31:0] rt_value,    
    output     [  4:0] rs,          
    output     [  4:0] rt,          
    output     [ 32:0] jbr_bus,     
    output             ID_over, 
    output     [174:0] ID_EXE_bus,  
    input              inst_addr_ok ,

    input              IF_over,     
    input      [  4:0] EXE_wdest,   
    input      [ 31:0] EXE__result,
    input              EXE_load,
    input      [  4:0] MEM_wdest,   
    input      [ 31:0] MEM__result,
    input              MEM_load,
    input              MEM_valid_r, 
    output             load_relate1,
    output             load_relate2 
);
//-----{IF->ID}begin
    wire [31:0] pc;
    wire [31:0] inst;
    assign {pc, inst} = IF_ID_bus_r;  // IF->ID
//-----{IF->ID}end

//-----{??}begin
    wire [5:0] op;       
    wire [4:0] rd;       
    wire [4:0] sa;      
    wire [5:0] funct;    
    wire [15:0] imm;     
    wire [15:0] offset;  
    wire [25:0] target;  
    wire [2:0] cp0r_sel;

    assign op     = inst[31:26];  
    assign rs     = inst[25:21];  
    assign rt     = inst[20:16];  
    assign rd     = inst[15:11];  
    assign sa     = inst[10:6];   
    assign funct  = inst[5:0];    
    assign imm    = inst[15:0];   
    assign offset = inst[15:0];   
    assign target = inst[25:0];  
    assign cp0r_sel= inst[2:0];   // cp0 select
    

    wire inst_ADDU, inst_SUBU , inst_SLT , inst_AND;
    wire inst_NOR , inst_OR   , inst_XOR , inst_SLL;
    wire inst_SRL , inst_ADDIU, inst_BEQ , inst_BNE;
    wire inst_LW  , inst_SW   , inst_LUI , inst_J;
    wire inst_SLTU, inst_JALR , inst_JR  , inst_SLLV;
    wire inst_SRA , inst_SRAV , inst_SRLV, inst_SLTIU;
    wire inst_SLTI, inst_BGEZ , inst_BGTZ, inst_BLEZ;
    wire inst_BLTZ, inst_LB   , inst_LBU , inst_SB;
    wire inst_ANDI, inst_ORI  , inst_XORI, inst_JAL;
    wire inst_MULT, inst_MFLO , inst_MFHI, inst_MTLO;
    wire inst_MTHI, inst_MFC0 , inst_MTC0;
    wire inst_ERET, inst_SYSCALL;
    
    wire inst_ADDI, inst_ADD, inst_SUB;

    wire inst_DIV, inst_DIVU, inst_MULTU, inst_BGEZAL, inst_BLTZAL;
    wire inst_LH, inst_LHU, inst_LWL, inst_LWR;
    wire inst_SH, inst_SWL, inst_SWR;

    wire inst_BREAK;
    
    wire op_zero;
    wire sa_zero;
    assign op_zero = ~(|op);
    assign sa_zero = ~(|sa);
    assign inst_ADD   = op_zero & sa_zero & (funct == 6'b100000);
    assign inst_ADDU  = op_zero & sa_zero & (funct == 6'b100001);
    assign inst_ADDIU = (op == 6'b001001);
    assign inst_ADDI  = (op == 6'b001000);
    
    assign inst_SUB   = op_zero & sa_zero & (funct == 6'b100010);
    assign inst_SUBU  = op_zero & sa_zero & (funct == 6'b100011);
    
    assign inst_SLT   = op_zero & sa_zero & (funct == 6'b101010);
    assign inst_SLTU  = op_zero & sa_zero & (funct == 6'b101011);
    assign inst_SLTI  = (op == 6'b001010);
    assign inst_SLTIU = (op == 6'b001011);

    assign inst_DIV   = op_zero & (rd == 5'b00000)
                        & sa_zero & (funct == 6'b011010);
    assign inst_DIVU  = op_zero & (rd == 5'b00000)
                        & sa_zero & (funct == 6'b011011);

    assign inst_MULT  = op_zero & (rd==5'b00000)
                      & sa_zero & (funct == 6'b011000);
    assign inst_MULTU = op_zero & (rd == 5'b00000)
                      & sa_zero & (funct == 6'b011001);

    assign inst_AND   = op_zero & sa_zero & (funct == 6'b100100);
    assign inst_ANDI  = (op == 6'b001100);
    assign inst_LUI   = (op == 6'b001111) & (rs==5'd0);
    assign inst_NOR   = op_zero & sa_zero & (funct == 6'b100111);
    assign inst_OR    = op_zero & sa_zero & (funct == 6'b100101);
    assign inst_XOR   = op_zero & sa_zero & (funct == 6'b100110);
    assign inst_ORI   = (op == 6'b001101);
    assign inst_XORI  = (op == 6'b001110);

    assign inst_SLL   = op_zero & (rs==5'd0) & (funct == 6'b000000);
    assign inst_SLLV  = op_zero & sa_zero    & (funct == 6'b000100);
    assign inst_SRA   = op_zero & (rs==5'd0) & (funct == 6'b000011);
    assign inst_SRAV  = op_zero & sa_zero    & (funct == 6'b000111);
    assign inst_SRL   = op_zero & (rs==5'd0) & (funct == 6'b000010);
    assign inst_SRLV  = op_zero & sa_zero    & (funct == 6'b000110);

    assign inst_BEQ   = (op == 6'b000100);
    assign inst_BGEZ  = (op == 6'b000001) & (rt==5'd1);
    assign inst_BGTZ  = (op == 6'b000111) & (rt==5'd0);
    assign inst_BLEZ  = (op == 6'b000110) & (rt==5'd0);
    assign inst_BLTZ  = (op == 6'b000001) & (rt==5'd0);
    assign inst_BGEZAL  = (op == 6'b000001) & (rt == 5'b10001);
    assign inst_BLTZAL  = (op == 6'b000001) & (rt == 5'b10000); 
    assign inst_BNE   = (op == 6'b000101);
    assign inst_J     = (op == 6'b000010);
    assign inst_JAL   = (op == 6'b000011);

    wire ri_ex;
    assign ri_ex = pc[1:0] == 2'b0 & (~(inst_ADDU | inst_SUBU | inst_SLT | inst_AND |
                   inst_NOR  | inst_OR   | inst_XOR | inst_SLL |
                   inst_SRL  | inst_ADDIU| inst_BEQ | inst_BNE |
                   inst_LW   | inst_SW   | inst_LUI | inst_J   |
                   inst_SLTU | inst_JALR | inst_JR  | inst_SLLV|
                   inst_SRA  | inst_SRAV | inst_SRLV| inst_SLTIU|
                   inst_SLTI | inst_BGEZ | inst_BGTZ| inst_BLEZ|
                   inst_BLTZ | inst_LB   | inst_LBU | inst_SB  |
                   inst_ANDI | inst_ORI  | inst_XORI| inst_JAL |
                   inst_MULT | inst_MFLO | inst_MFHI| inst_MTLO|
                   inst_MTHI | inst_MFC0 | inst_MTC0|
                   inst_ERET | inst_SYSCALL|
                   inst_ADDI | inst_ADD  | inst_SUB |
                   inst_DIV  | inst_DIVU | inst_MULTU | inst_BGEZAL | inst_BLTZAL |
                   inst_LH   | inst_LHU  | inst_LWL | inst_LWR |
                   inst_SH   | inst_SWL  | inst_SWR |
                   inst_BREAK));
    assign inst_JALR  = op_zero & (rt==5'd0) & (rd==5'd31)
                      & sa_zero & (funct == 6'b001001);
    assign inst_JR    = op_zero & (rt==5'd0) & (rd==5'd0 )
                      & sa_zero & (funct == 6'b001000);

    assign inst_MFLO  = op_zero & (rs==5'd0) & (rt==5'd0)
                      & sa_zero & (funct == 6'b010010);
    assign inst_MFHI  = op_zero & (rs==5'd0) & (rt==5'd0)
                      & sa_zero & (funct == 6'b010000);
    assign inst_MTLO  = op_zero & (rt==5'd0) & (rd==5'd0)
                      & sa_zero & (funct == 6'b010011);
    assign inst_MTHI  = op_zero & (rt==5'd0) & (rd==5'd0)
                      & sa_zero & (funct == 6'b010001);

    assign inst_SYSCALL = (op == 6'b000000) & (funct == 6'b001100);
    assign inst_BREAK = (op == 6'b000000) & (funct == 6'b001101);

    assign inst_LW    = (op == 6'b100011);
    assign inst_SW    = (op == 6'b101011);
    assign inst_LB    = (op == 6'b100000);
    assign inst_LBU   = (op == 6'b100100);
    assign inst_LH    = (op == 6'b100001);
    assign inst_LHU   = (op == 6'b100101);
    assign inst_SB    = (op == 6'b101000);
    assign inst_SH    = (op == 6'b101001);
    assign inst_LWL   = (op == 6'b100010);
    assign inst_LWR   = (op == 6'b100110);
    assign inst_SWL   = (op == 6'b101010);
    assign inst_SWR   = (op == 6'b101110);
    
    assign inst_MFC0    = (op == 6'b010000) & (rs==5'd0) 
                        & sa_zero & (funct[5:3] == 3'b000);
    assign inst_MTC0    = (op == 6'b010000) & (rs==5'd4)
                        & sa_zero & (funct[5:3] == 3'b000);
    assign inst_ERET    = (op == 6'b010000) & (rs==5'd16) & (rt==5'd0)
                        & (rd==5'd0) & sa_zero & (funct == 6'b011000);

    

    wire inst_jr;    
    wire inst_j_link;
    wire inst_jbr;   
    assign inst_jr     = inst_JALR | inst_JR;
    assign inst_j_link = inst_JAL | inst_JALR | inst_BLTZAL | inst_BGEZAL;
    assign inst_jbr = inst_J    | inst_JAL  | inst_jr
                    | inst_BEQ  | inst_BNE  | inst_BGEZ
                    | inst_BGTZ | inst_BLEZ | inst_BLTZ
                    | inst_BLTZAL | inst_BGEZAL;
    
    //load store
    wire inst_load;
    wire inst_store;
    assign inst_load  = inst_LW | inst_LB | inst_LBU |
                        inst_LH | inst_LHU| inst_LWL |
                        inst_LWR;
    assign inst_store = inst_SW | inst_SB | inst_SH |
                        inst_SWL| inst_SWR;
    
    //alu operation
    wire inst_add, inst_sub, inst_slt,inst_sltu;
    wire inst_and, inst_nor, inst_or, inst_xor;
    wire inst_sll, inst_srl, inst_sra,inst_lui;
    assign inst_add = inst_ADDU | inst_ADDIU | inst_load
                    | inst_store | inst_j_link | inst_ADD
                    | inst_ADDI;
    assign inst_sub = inst_SUBU | inst_SUB;               
    assign inst_slt = inst_SLT | inst_SLTI;                
    assign inst_sltu= inst_SLTIU | inst_SLTU;             
    assign inst_and = inst_AND | inst_ANDI;                
    assign inst_nor = inst_NOR;                            
    assign inst_or  = inst_OR  | inst_ORI;                
    assign inst_xor = inst_XOR | inst_XORI;
    assign inst_sll = inst_SLL | inst_SLLV;
    assign inst_srl = inst_SRL | inst_SRLV;
    assign inst_sra = inst_SRA | inst_SRAV;
    assign inst_lui = inst_LUI;
    
    // ????sa?
    wire inst_shf_sa;
    assign inst_shf_sa =  inst_SLL | inst_SRL | inst_SRA;
    
    // ???????????
    wire inst_imm_zero; // 0??
    wire inst_imm_sign; // ?????
    assign inst_imm_zero = inst_ANDI  | inst_LUI  | inst_ORI | inst_XORI;
    assign inst_imm_sign = inst_ADDIU | inst_SLTI | inst_SLTIU
                         | inst_load | inst_store | inst_ADDI;
    
    // ????????
    wire inst_wdest_rt;  // ???rt???
    wire inst_wdest_31;  // 31????
    wire inst_wdest_rd;  // rd???
    assign inst_wdest_rt = inst_imm_zero | inst_ADDIU | inst_SLTI
                         | inst_SLTIU | inst_load | inst_MFC0 
                         | inst_ADDI;
    assign inst_wdest_31 = inst_JAL | inst_BGEZAL | inst_BLTZAL;
    assign inst_wdest_rd = inst_ADDU | inst_SUBU | inst_SLT  | inst_SLTU
                         | inst_JALR | inst_AND  | inst_NOR  | inst_OR 
                            | inst_XOR  | inst_SLL  | inst_SLLV | inst_SRA 
                         | inst_SRAV | inst_SRL  | inst_SRLV
                         | inst_MFHI | inst_MFLO | inst_ADD | inst_SUB;
                         

    wire inst_no_rs;  
    wire inst_no_rt;  
    assign inst_no_rs = inst_MTC0 | inst_SYSCALL | inst_ERET | inst_BREAK;
    assign inst_no_rt = inst_ADDIU | inst_SLTI | inst_SLTIU
                      | inst_BGEZ  | inst_load | inst_imm_zero
                      | inst_J     | inst_JAL  | inst_MFC0
                      | inst_SYSCALL | inst_ADDI | inst_BREAK;
//-----end
    
//-----begin
    //bd_pc,PC+4
    wire [31:0] rs_value_related;
    wire [31:0] rt_value_related;
    assign rs_value_related = !(|rs)            ? 31'b0       :     
                              (EXE_wdest == rs) ? EXE__result : 
                              (MEM_wdest == rs) ? MEM__result :
                              rs_value;   
    assign rt_value_related = !(|rt)            ? 31'b0       :
                              (EXE_wdest == rt) ? EXE__result : 
                              (MEM_wdest == rt) ? MEM__result :
                              rt_value;
    
    wire [31:0] bd_pc;   
    assign bd_pc = pc + 3'b100;
    
    wire        j_taken;
    wire [31:0] j_target;
    assign j_taken = inst_J | inst_JAL | inst_jr;
    assign j_target = inst_jr ? rs_value_related : {bd_pc[31:28],target,2'b00};

    //branch
    wire rs_equql_rt;
    wire rs_ez;
    wire rs_ltz;
    assign rs_equql_rt = rs_value_related == rt_value_related;  // GPR[rs]==GPR[rt]
    assign rs_ez       = ~(|rs_value_related);            // rs=0
    assign rs_ltz      = rs_value_related[31];            // rs<0
    wire br_taken;
    wire [31:0] br_target;
    assign br_taken = inst_BEQ  & rs_equql_rt
                    | inst_BNE  & ~rs_equql_rt
                    | (inst_BGEZ | inst_BGEZAL) & ~rs_ltz
                    | inst_BGTZ & ~rs_ltz & ~rs_ez
                    | inst_BLEZ & (rs_ltz | rs_ez)
                    | (inst_BLTZ | inst_BLTZAL) & rs_ltz;

    assign br_target[31:2] = bd_pc[31:2] + {{14{offset[15]}}, offset};  
    assign br_target[1:0]  = bd_pc[1:0];
    

    wire jbr_taken;
    reg  jbr_taken_;
    wire [31:0] jbr_target;
    
    always @(posedge clk) 
    begin
        if(inst_addr_ok)
        begin
            jbr_taken_ <= 1'b0;
        end
        else if(ID_valid)
        begin
            jbr_taken_ <= jbr_taken;
        end
    end    

    assign jbr_target = j_taken ? j_target : br_target;
    assign jbr_taken = ID_valid ? ((j_taken | br_taken) & ID_over) :jbr_taken_; 

    assign jbr_bus = {jbr_taken, jbr_target};
//-----end


    assign load_relate1 = (ID_valid && EXE_load && ((EXE_wdest == rs) || (EXE_wdest == rt))) ? 1'b1 : 1'b0;
    assign load_relate2 = (ID_valid && MEM_load && ((MEM_wdest == rs) || (MEM_wdest == rt)) && !MEM_valid_r) ? 1'b1 : 1'b0;

    wire ID_valid_;
    assign ID_valid_ = load_relate1 ? 1'b0 :
                       load_relate2 ? 1'b0 :
                       ID_valid;
    reg IF_over_;
    always @(posedge clk) 
    begin
        IF_over_ <= IF_over;
    end

    //assign ID_over = ID_valid_  & (~inst_jbr | IF_over_);
    assign ID_over = ID_valid_  & IF_over_;

    wire ID_multiply;         
    wire divider;
    wire mthi;             //MTHI
    wire mtlo;             //MTLO
    assign ID_multiply = ( inst_MULT | inst_MULTU ) & ID_valid_;
    assign divider = inst_DIV | inst_DIVU;
    assign mthi     = inst_MTHI;
    assign mtlo     = inst_MTLO;

    wire [11:0] alu_control;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;
    

    assign alu_operand1 = inst_j_link ? pc : 
                          inst_shf_sa ? {27'd0,sa} : 
                          rs_value_related;
    assign alu_operand2 = inst_j_link ? 32'd8 :  
                          inst_imm_zero ? {16'd0, imm} :
                          inst_imm_sign ?  {{16{imm[15]}}, imm} : 
                          rt_value_related;
    assign alu_control = {inst_add,        
                          inst_sub,
                          inst_slt,
                          inst_sltu,
                          inst_and,
                          inst_nor,
                          inst_or, 
                          inst_xor,
                          inst_sll,
                          inst_srl,
                          inst_sra,
                          inst_lui};

    wire l_unsign;  // unsigned load
    wire ls_word;   //load/store instruction
    wire ls_dbyte;
    wire [4:0] mem_control;  //MEM
    wire [31:0] store_data;  //store
    assign l_unsign = inst_LBU | inst_LHU;
    assign ls_dbyte = inst_LH | inst_LHU | inst_LH | inst_SH;
    assign ls_word = inst_LW | inst_SW;
    assign mem_control = {inst_load,
                          inst_store,
                          ls_word,
                          ls_dbyte,
                          l_unsign };
                          

    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   
    wire       break;
    wire       eret;
    wire       rf_wen;    
    wire [4:0] rf_wdest;  
    assign syscall  = inst_SYSCALL;
    assign break    = inst_BREAK;
    assign eret     = inst_ERET;
    assign mfhi     = inst_MFHI;
    assign mflo     = inst_MFLO;
    assign mtc0     = inst_MTC0;
    assign mfc0     = inst_MFC0;
    assign cp0r_addr= {rd,cp0r_sel};
    assign rf_wen   = (inst_wdest_rt | inst_wdest_31 | inst_wdest_rd) & ~(|pc[1:0]);
    assign rf_wdest = inst_wdest_rt ? rt :     
                      inst_wdest_31 ? 5'd31 :  
                      inst_wdest_rd ? rd : 5'd0;
    assign store_data = rt_value_related;
    wire unsined_op;
    wire add_sub;
    assign add_sub = inst_ADD | inst_ADDI | inst_SUB;
    assign unsined_op = inst_MULTU | inst_DIVU;
    assign ID_EXE_bus = {inst_jbr & ~(|pc[1:0]),ID_multiply,divider,unsined_op,mthi,mtlo,                  
                         alu_control,alu_operand1,alu_operand2,
                         mem_control,store_data,              
                         mfhi,mflo,                           
                         mtc0,mfc0,cp0r_addr,syscall,break,add_sub,ri_ex,eret,    
                         rf_wen, rf_wdest,                    
                         pc};                               
//-----{ID->EXE}end

endmodule
