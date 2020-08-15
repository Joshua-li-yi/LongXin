`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/01 23:28:01
// Design Name: 
// Module Name: mycpu_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sram_like_cpu(
	input clk,           
    input resetn,        
    input [ 5:0]ext_int, // interrupt,high active
    
    //inst sram-like 
    output         inst_req     ,
    output         inst_wr      ,
    output  [1 :0] inst_size    ,
    output  [31:0] inst_addr    ,
    output  [31:0] inst_wdata   ,
    input   [31:0] inst_rdata   ,
    input          inst_addr_ok ,
    input          inst_data_ok ,
    
    //data sram-like 
    output         data_req     ,
    output         data_wr      ,
    output  [1 :0] data_size    ,
    output  [31:0] data_addr    ,
    output  [31:0] data_wdata   ,
    input   [31:0] data_rdata   ,
    input          data_addr_ok ,
    input          data_data_ok ,

	output [31:0] debug_wb_pc,
	output [ 3:0] debug_wb_rf_wen,
	output [ 4:0] debug_wb_rf_wnum,
	output [31:0] debug_wb_rf_wdata    
    );
    
    wire [31:0]IF_pc;
    wire [31:0]IF_inst;
    wire [31:0]ID_pc;
    wire [31:0]EXE_pc;
    wire [31:0]MEM_pc;
    wire [31:0] HI_data; 
    wire [31:0] LO_data; 


    reg IF_valid;
    reg ID_valid;
    reg EXE_valid;
    reg MEM_valid;
    reg WB_valid;

    wire IF_over;
    wire ID_over;
    wire EXE_over;
    wire MEM_over;
    wire WB_over;

    wire IF_allow_in;
    wire ID_allow_in;
    wire EXE_allow_in;
    wire MEM_allow_in;
    wire WB_allow_in;
    
    wire cancel;    
    
    assign IF_allow_in  = (resetn & ID_allow_in) | cancel;
    assign ID_allow_in  = ~ID_valid  | (ID_over  & EXE_allow_in);
    assign EXE_allow_in = ~EXE_valid | (EXE_over & MEM_allow_in);
    assign MEM_allow_in = ~MEM_valid | (MEM_over & WB_allow_in );
    assign WB_allow_in  = ~WB_valid  | WB_over;
    
   always @(posedge clk)
    begin
        if (!resetn)
        begin
            IF_valid <= 1'b0;
        end
        else
        begin
            IF_valid <= 1'b1;
        end
    end
    
    //ID_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            ID_valid <= 1'b0;
        end
        else if (ID_allow_in)
        begin
            ID_valid <= IF_over;
        end
    end
    
    //EXE_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            EXE_valid <= 1'b0;
        end
        else if (EXE_allow_in)
        begin
            EXE_valid <= ID_over;
        end
    end
    
    //MEM_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            MEM_valid <= 1'b0;
        end
        else if (MEM_allow_in)
        begin
            MEM_valid <= EXE_over;
        end
    end
    
    //WB_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            WB_valid <= 1'b0;
        end
        else if (WB_allow_in)
        begin
            WB_valid <= MEM_over;
        end
    end
    

    wire [ 63:0] IF_ID_bus;   // IF->ID
    wire [174:0] ID_EXE_bus;  // ID->EXE
    wire [159:0] EXE_MEM_bus; // EXE->MEM
    wire [156:0] MEM_WB_bus;  // MEM->WB
    
    reg [ 63:0] IF_ID_bus_r;
    reg [174:0] ID_EXE_bus_r;
    reg [159:0] EXE_MEM_bus_r;
    reg [156:0] MEM_WB_bus_r;
    
    always @(posedge clk)
    begin
        if(IF_over && ID_allow_in)
        begin
            IF_ID_bus_r <= IF_ID_bus;
        end
    end

    always @(posedge clk)
    begin
        if(ID_over && EXE_allow_in)
        begin
            ID_EXE_bus_r <= ID_EXE_bus;
        end
    end

    always @(posedge clk)
    begin
        if(EXE_over && MEM_allow_in)
        begin
            EXE_MEM_bus_r <= EXE_MEM_bus;
        end
    end    

    always @(posedge clk)
    begin
        if(MEM_over && WB_allow_in)
        begin
            MEM_WB_bus_r <= MEM_WB_bus;
        end
    end

    wire [ 32:0] jbr_bus;    


    wire [ 4:0] EXE_wdest;
    wire [31:0] EXE__result;
    wire        EXE_load;
    wire        EXE_multiply;
    wire        load_relate1;
    wire        load_relate2;
    wire [ 4:0] MEM_wdest;
    wire [31:0] MEM__result;
    wire        MEM_load;
    wire        MEM_valid_r;
    
    //hi&lo related
    wire [31:0] WB_hi_data;
    wire [31:0] WB_lo_data;
    wire        WB_hi_write;
    wire        WB_lo_write;
    wire [31:0] cp0r_status;
    wire [31:0] cp0r_cause;
    wire [31:0] cp0r_epc;
    wire [31:0] cp0r_badvaddr; 
    wire        MEM_mfhi;
    wire        MEM_mflo;
    wire        MEM_hi_write;
    wire        MEM_lo_write;
    wire [31:0] MEM_hi_data;
    wire [31:0] MEM_lo_data;

    wire [ 4:0] rs;
    wire [ 4:0] rt;   
    wire [31:0] rs_value;
    wire [31:0] rt_value;
    
    wire        rf_wen;
    wire [ 4:0] rf_wdest;
    wire [31:0] rf_wdata;
   
    
    wire [32:0] exc_bus;

    fetch IF_module(             // ???
        .clk         (clk            ),  // I, 1
        .resetn      (resetn         ),  // I, 1
        .IF_valid    (IF_valid       ),  // I, 1
        .IF_allow_in (IF_allow_in    ),  // I, 1
        .jbr_bus     (jbr_bus        ),  // I, 33
        .IF_over     (IF_over        ),  // O, 1
        .IF_ID_bus   (IF_ID_bus      ),  // O, 64
        
        //5???????
        .exc_bus     (exc_bus        ),  // I, 32
        .EXE_multiply(EXE_multiply   ),// I, 1 
        .MEM_over    (MEM_over       ),// I, 1
        .MEM_valid_r (MEM_valid_r    ),// I, 1
        .load_relate1(load_relate1   ),// O, 1
        .load_relate2(load_relate2   ),// O, 1
        .WB_valid    (WB_valid       ),  // I, 1

        //类SRAM新增接口
        .inst_req    (inst_req    ),// O, 1
        .inst_wr     (inst_wr     ),// O, 1
        .inst_size   (inst_size   ),// O, 2
        .inst_addr   (inst_addr   ),// O, 32
        .inst_wdata  (inst_wdata  ),// O, 32
        .inst_rdata  (inst_rdata  ),// I, 32
        .inst_addr_ok(inst_addr_ok),// I, 1
        .inst_data_ok(inst_data_ok) // I, 1
    );
    
    decode ID_module(               // ???
        .clk        (clk        ),  // I, 1
        .ID_valid   (ID_valid   ),  // I, 1
        .ID_allow_in(ID_allow_in),
        .IF_ID_bus_r(IF_ID_bus_r),  // I, 64
        .rs_value   (rs_value   ),  // I, 32
        .rt_value   (rt_value   ),  // I, 32
        .rs         (rs         ),  // O, 5
        .rt         (rt         ),  // O, 5
        .jbr_bus    (jbr_bus    ),  // O, 33
        .ID_over    (ID_over    ),  // O, 1
        .ID_EXE_bus (ID_EXE_bus ),  // O, 167
        .inst_addr_ok(inst_addr_ok),// I, 1

        //5?????
        .IF_over     (IF_over     ),// I, 1
        .EXE_wdest   (EXE_wdest   ),// I, 5
        .EXE__result (EXE__result ),// I, 32
        .EXE_load    (EXE_load    ),
        .MEM_wdest   (MEM_wdest   ),// I, 5
        .MEM__result (MEM__result ),// I, 32
        .MEM_load    (MEM_load    ),
        .MEM_valid_r (MEM_valid_r ),// I, 1
        .load_relate1(load_relate1),// O, 1
        .load_relate2(load_relate2) // O, 1
    ); 

    exe EXE_module(                   // ???
        .EXE_valid   (EXE_valid   ),  // I, 1
        .ID_EXE_bus_r(ID_EXE_bus_r),  // I, 167
        .EXE_over    (EXE_over    ),  // O, 1 
        .EXE_MEM_bus (EXE_MEM_bus ),  // O, 154
        
        //5?????
        .clk         (clk         ),  // I, 1
        .EXE_wdest   (EXE_wdest   ), // O, 5
        .EXE__result (EXE__result ),
        .EXE_load    (EXE_load    ),
        .EXE_multiply(EXE_multiply), // O, 1

        //new
        //hi & lo related
        .HI_data      (HI_data      ),
        .LO_data      (LO_data      ),
        .WB_hi_data   (WB_hi_data   ),
        .WB_lo_data   (WB_lo_data   ),
        .WB_hi_write  (WB_hi_write  ),
        .WB_lo_write  (WB_lo_write  ),
        .cp0r_status  (cp0r_status  ),
        .cp0r_cause   (cp0r_cause   ),
        .cp0r_epc     (cp0r_epc     ),
        .cp0r_badvaddr(cp0r_badvaddr), 
        .MEM_mfhi     (MEM_mfhi     ),
        .MEM_mflo     (MEM_mflo     ),
        .MEM_hi_write (MEM_hi_write ),
        .MEM_lo_write (MEM_lo_write ),
        .MEM_hi_data  (MEM_hi_data  ),
        .MEM_lo_data  (MEM_lo_data  )   
    );

    mem MEM_module(                     // ???
        .clk          (clk            ),  // I, 1 
        .resetn       (resetn         ),  // I, 1
        .cancel       (cancel         ),  //
        .MEM_valid    (MEM_valid      ),  // I, 1
        .EXE_MEM_bus_r(EXE_MEM_bus_r  ),  // I, 154
        .MEM_over     (MEM_over       ),  // O, 1
        .MEM_WB_bus   (MEM_WB_bus     ),  // O, 123
        
        //5???????
        .MEM_allow_in (MEM_allow_in   ),  // I, 1
        .MEM_wdest    (MEM_wdest      ),  // O, 5
        .MEM__result  (MEM__result    ),
        .MEM_load     (MEM_load       ),
        .MEM_valid_r  (MEM_valid_r    ),

        //hi&lo related
        .HI_data      (HI_data        ),
        .LO_data      (LO_data        ),
        .WB_hi_data   (WB_hi_data     ),
        .WB_lo_data   (WB_lo_data     ),
        .WB_hi_write  (WB_hi_write    ),
        .WB_lo_write  (WB_lo_write    ),
        .cp0r_status  (cp0r_status    ),
        .cp0r_cause   (cp0r_cause     ),
        .cp0r_epc     (cp0r_epc       ),
        .cp0r_badvaddr(cp0r_badvaddr  ), 
        .MEM_mfhi     (MEM_mfhi       ),
        .MEM_mflo     (MEM_mflo       ),
        .MEM_hi_write (MEM_hi_write   ),
        .MEM_lo_write (MEM_lo_write   ),
        .MEM_hi_data  (MEM_hi_data    ),
        .MEM_lo_data  (MEM_lo_data    ),

        //类sram新增接口
        .data_req     (data_req     ),  // O, 1
        .data_wr      (data_wr      ),  // O, 1
        .data_size    (data_size    ),  // O, 2
        .data_addr    (data_addr    ),  // O, 32
        .data_wdata   (data_wdata   ),  // O, 32
        .data_rdata   (data_rdata   ),  // I, 32
        .data_addr_ok (data_addr_ok ),  // I, 1
        .data_data_ok (data_data_ok )   // I, 1           
    );          
    
    wb WB_module(                     // ???
        .WB_valid     (WB_valid     ),  // I, 1
        .MEM_WB_bus_r (MEM_WB_bus_r ),  // I, 123
        .rf_wen       (rf_wen       ),  // O, 1
        .rf_wdest     (rf_wdest     ),  // O, 5
        .rf_wdata     (rf_wdata     ),  // O, 32
        .WB_over      (WB_over      ),  // O, 1
        .inst_addr_ok (inst_addr_ok ),// I, 1

        .clk          (clk          ),  // I, 1
        .resetn       (resetn       ),  // I, 1
        .exc_bus      (exc_bus      ),  // O, 32
        .cancel       (cancel       ),  // O, 1
        
        .WB_pc        (debug_wb_pc  ),  // O, 32
        .ext_int      (ext_int      ),
        .WB_allow_in  (WB_allow_in  ),
        .MEM_over     (MEM_over     ),

        //hi & lo related
        .HI_data      (HI_data      ),  // O, 32
        .LO_data      (LO_data      ),  // O, 32
        .WB_hi_data   (WB_hi_data   ),
        .WB_lo_data   (WB_lo_data   ),
        .WB_hi_write  (WB_hi_write  ),
        .WB_lo_write  (WB_lo_write  ),
        .cp0r_status  (cp0r_status  ),
        .cp0r_cause   (cp0r_cause   ),
        .cp0r_epc     (cp0r_epc     ),
        .cp0r_badvaddr(cp0r_badvaddr)
    );

    regfile rf_module(
        .clk                (clk              ),
        .wen                (rf_wen           ),
        .raddr1             (rs               ),
        .raddr2             (rt               ),
        .waddr              (rf_wdest         ),
        .wdata              (rf_wdata         ),
        .rdata1             (rs_value         ),
        .rdata2             (rt_value         ),
        .debug_wb_rf_wen    (debug_wb_rf_wen  ),
        .debug_wb_rf_wnum   (debug_wb_rf_wnum ),
        .debug_wb_rf_wdata  (debug_wb_rf_wdata)
    );

endmodule
