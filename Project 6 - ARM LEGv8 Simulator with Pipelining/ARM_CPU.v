`timescale 1ns / 1ps

/*
	Phase 1: Start to IDEX (Complete)
    Phase 2: IDEX to MEM/WB
    Phase 3: Full & Debugging/Testing
*/

module ALUMux
(
  input [63:0] input1,
  input [63:0] input2,
  input CONTROL_ALUSRC,
  output reg [63:0] out
);
  
  always @(input1, input2, CONTROL_ALUSRC, out) begin
    
    if (CONTROL_ALUSRC == 0) begin
      out = input1;
    end
    
    else begin
      out = input2;
    end 
  end
  
endmodule

module ALU
(
  input [63:0] A,
  input [63:0] B,
  input [3:0] CONTROL,
  output reg [63:0] RESULT,
  output reg ZEROFLAG
);
  
  always @(A or B or CONTROL) begin
    case (CONTROL)
      4'b0000 : RESULT = A & B;
      4'b0001 : RESULT = A | B;
      4'b0010 : RESULT = A + B;
      4'b0110 : RESULT = A - B;
      4'b0111 : RESULT = B;
      4'b1100 : RESULT = ~(A | B);
    endcase

    if (RESULT == 0) begin
      ZEROFLAG = 1'b1;
    end else begin
      ZEROFLAG = 1'b0;
    end
  end
  
endmodule

module ALU_Control
(
  input [1:0] ALU_Op,
  input [10:0] ALU_INSTRUCTION,
  output reg [3:0] ALU_Out
);

  always @(ALU_Op or ALU_INSTRUCTION) begin
    
    case (ALU_Op)
      2'b00 : ALU_Out = 4'b0010;
      2'b01 : ALU_Out = 4'b0111;
      2'b10 : begin
       
        case (ALU_INSTRUCTION)
          11'b10001011000 : ALU_Out = 4'b0010; // ADD
          11'b11001011000 : ALU_Out = 4'b0110; // SUB
          11'b10001010000 : ALU_Out = 4'b0000; // AND
          11'b10101010000 : ALU_Out = 4'b0001; // ORR
        endcase
        
      end
    endcase
    
  end
  
endmodule

module ShiftLeft2
(
  input [63:0] inputData,
  output reg [63:0] outputData
);
  
  always @(inputData) begin
    outputData = inputData << 2;
  end
  
endmodule
 
module ARM_CPU
(
  input CLOCK,
  input [31:0] IC,
  output reg [63:0] PC
);
  
  initial begin 
	PC = 0;
  end
  
  always @(posedge CLOCK) begin
	PC <= PC + 4;
  end

  wire [63:0] IFID_PC;
  wire [31:0] IFID_IC;
  IFID cache1 (PC, IC, IFID_PC, IFID_IC);

  wire [1:0] control_aluop;
  wire control_alusrc;
  wire control_isZeroBranch;
  wire control_isUnconBranch;
  wire control_memRead;
  wire control_memwrite;
  wire control_regwrite;
  wire control_mem2reg;
  wire control_reg2loc;
  Control maine (IFID_IC[31:21], control_reg2loc, control_aluop, control_alusrc, control_isZeroBranch, control_isUnconBranch, control_memRead, control_memwrite, control_regwrite, control_mem2reg);
  
  wire [4:0] temp_reg2_in;
  Mux2 laa(IFID_IC[20:16], IFID_IC[4:0], control_reg2loc, temp_reg2_in);
  
  wire [63:0] reg_data_1;
  wire [63:0] reg_data_2;
  Register inna(IFID_IC[9:5], temp_reg2_in, reg_data_1, reg_data_2);
  
  wire [63:0] temp_sign_extend;
  SignExtend tooe (IFID_IC, temp_sign_extend);
  
  wire [1:0] IDEX_aluop;
  wire IDEX_alusrc;
  wire IDEX_isZeroBranch;
  wire IDEX_isUnconBranch;
  wire IDEX_memRead;
  wire IDEX_memwrite;
  wire IDEX_regwrite;
  wire IDEX_mem2reg;
  wire [63:0] IDEX_reg_data_1;
  wire [63:0] IDEX_reg_data_2;
  wire [63:0] IDEX_PC;
  wire [63:0] IDEX_sign_extend_out;
  wire [10:0] IDEX_alu_control_out;
  wire [4:0] IDEX_write_reg_out;
  
  IDEX cache2 (control_aluop, control_alusrc, control_isZeroBranch, control_isUnconBranch, control_memRead, control_memwrite, control_regwrite, control_mem2reg, IFID_PC, reg_data_1, reg_data_2, temp_sign_extend, IFID_IC[31:21], IFID_IC[4:0], IDEX_aluop, IDEX_alusrc, IDEX_isZeroBranch, IDEX_isUnconBranch, IDEX_memRead, IDEX_memwrite, IDEX_regwrite, IDEX_mem2reg, IDEX_PC, IDEX_reg_data_1, IDEX_reg_data_2, IDEX_sign_extend_out, IDEX_alu_control_out, IDEX_write_reg_out);

  wire [63:0] temp_shifted_val;
  ShiftLeft2 laas(IDEX_sign_extend_out, temp_shifted_val);
  
  wire [63:0] shiftPC;
  wire temp_shift_zero; //unused wire
  ALU adderShiftPC(IDEX_PC, temp_shifted_val, 4'b0010, shiftPC, temp_shift_zero);
  
  
  wire [3:0] tempALUControl;
  ALU_Control mod3(IDEX_aluop, IDEX_alu_control_out, tempALUControl);
  
  
  wire [63:0] tempALUInput2;
  ALUMux mux3(IDEX_reg_data_2, IDEX_sign_extend_out, IDEX_alusrc, tempALUInput2);
  
  wire [63:0] ALU_Result_Out;
  wire tempALUZero;
  ALU aluResult(IDEX_reg_data_1, tempALUInput2, tempALUControl, ALU_Result_Out, tempALUZero);
  

  wire EXMEM_isZeroBranch;
  wire EXMEM_isUnconBranch;
  wire EXMEM_memRead;
  wire EXMEM_memwrite;
  wire EXMEM_regwrite;
  wire EXMEM_mem2reg;
  wire [63:0] EXMEM_shifted_PC_out;
  wire EXMEM_alu_zero_out;
  wire [63:0] EXMEM_alu_result_out;
  wire [63:0] EXMEM_write_data_mem_out;
  wire [4:0] EXMEM_write_reg_out;
  EXMEM cache3(IDEX_isZeroBranch, IDEX_isUnconBranch, IDEX_memRead, IDEX_memwrite, IDEX_regwrite, IDEX_mem2reg, shiftPC, tempALUZero, ALU_Result_Out, IDEX_reg_data_2, IDEX_write_reg_out, EXMEM_isZeroBranch, EXMEM_isUnconBranch, EXMEM_memRead, EXMEM_memwrite, EXMEM_regwrite, EXMEM_mem2reg, EXMEM_shifted_PC_out, EXMEM_alu_zero_out, EXMEM_alu_result_out, EXMEM_write_data_mem_out, EXMEM_write_reg_out);
  

   always @(IFID_IC) begin
     $display("Cache1 -> IC = %h | PC = %d", IFID_IC, IFID_PC);
     $display("Cache2 -> PC = %d | %b %b | %b %b %b | %b %b", IDEX_PC, IDEX_regwrite, IDEX_mem2reg, IDEX_isUnconBranch, IDEX_memRead, IDEX_memwrite, IDEX_aluop, IDEX_alusrc);
     $display("       -> %d %d | %d %b %d", IDEX_reg_data_1, IDEX_reg_data_2, IDEX_sign_extend_out, IDEX_alu_control_out, IDEX_write_reg_out); 
     $display("--------------------------------------------------------------------------------------");
              
  end
  
  
 

  /*
  always @(IFID_IC) begin
    $display("[%b] - %h = %b %b %b %b %b %b %b %b %d %d", CLOCK, IFID_IC, control_reg2loc, control_aluop, control_alusrc, control_isZeroBranch, control_isUnconBranch, control_memRead, control_memwrite, control_regwrite, control_mem2reg, IDEX_reg_data_1, IDEX_reg_data_2);
  end
  */

  
  
  
  
  
endmodule

module IFID
(
  input [63:0] PC_in,
  input [31:0] IC_in,
  output reg [63:0] PC_out,
  output reg [31:0] IC_out
);
  
  always @(*) begin
    PC_out <= PC_in;
    IC_out <= IC_in;
  end
endmodule


module IDEX 
(
  input [1:0] aluop_in, 	// EX Stage
  input alusrc_in, 			// EX Stage
  input isZeroBranch_in, 	// M Stage
  input isUnconBranch_in, 	// M Stage
  input memRead_in, 		// M Stage
  input memwrite_in, 		// M Stage
  input regwrite_in, 		// WB Stage
  input mem2reg_in, 		// WB Stage
  input [63:0] PC_in,		
  input [63:0] regdata1_in,
  input [63:0] regdata2_in,
  input [63:0] sign_extend_in,
  input [10:0] alu_control_in,
  input [4:0] write_reg_in,

  output reg [1:0] aluop_out, 	// EX Stage
  output reg alusrc_out, 		// EX Stage
  output reg isZeroBranch_out, 	// M Stage
  output reg isUnconBranch_out, // M Stage
  output reg memRead_out, 		// M Stage
  output reg memwrite_out, 		// M Stage
  output reg regwrite_out,		// WB Stage
  output reg mem2reg_out,		// WB Stage
  output reg [63:0] PC_out,
  output reg [63:0] regdata1_out,
  output reg [63:0] regdata2_out,
  output reg [63:0] sign_extend_out,
  output reg [10:0] alu_control_out,
  output reg [4:0] write_reg_out
);
  
  always @(*) begin
    /* Values for EX */
    aluop_out <= aluop_in;
	alusrc_out <= alusrc_in;
    
    /* Values for M */
  	isZeroBranch_out <= isZeroBranch_in;
    isUnconBranch_out <= isUnconBranch_in;
  	memRead_out <= memRead_in;
 	memwrite_out <= memwrite_in;
    
    /* Values for WB */
    regwrite_out <= regwrite_in;
  	mem2reg_out <= mem2reg_in;
    
    /* Values for all Stages */
    PC_out <= PC_in;
    regdata1_out <= regdata1_in;
    regdata2_out <= regdata2_in;
    
    /*  */
    sign_extend_out <= sign_extend_in;
  	alu_control_out <= alu_control_in;
  	write_reg_out <= write_reg_in;
  end
endmodule



module EXMEM
(
  input isZeroBranch_in, 	// M Stage
  input isUnconBranch_in, 	// M Stage
  input memRead_in, 		// M Stage
  input memwrite_in, 		// M Stage
  input regwrite_in, 		// WB Stage
  input mem2reg_in, 		// WB Stage
  input [63:0] shifted_PC_in,
  input alu_zero_in,
  input [63:0] alu_result_in,
  input [63:0] write_data_mem_in,
  input [4:0] write_reg_in,
    
  output reg isZeroBranch_out, 	// M Stage
  output reg isUnconBranch_out, // M Stage
  output reg memRead_out, 		// M Stage
  output reg memwrite_out, 		// M Stage
  output reg regwrite_out,		// WB Stage
  output reg mem2reg_out,		// WB Stage
  output reg [63:0] shifted_PC_out,
  output reg alu_zero_out,
  output reg [63:0] alu_result_out,
  output reg [63:0] write_data_mem_out,
  output reg [4:0] write_reg_out
);

  always @(*) begin

    /* Values for M */
  	isZeroBranch_out <= isZeroBranch_in;
    isUnconBranch_out <= isUnconBranch_in;
  	memRead_out <= memRead_in;
 	memwrite_out <= memwrite_in;
    
    /* Values for WB */
    regwrite_out <= regwrite_in;
  	mem2reg_out <= mem2reg_in;
    
    /* Values for all Stages */
    shifted_PC_out <= shifted_PC_in;
    alu_zero_out <= alu_zero_in;
    alu_result_out <= alu_result_in;
    write_data_mem_out <= write_data_mem_in;
	write_reg_out <= write_reg_in;
  end

endmodule

module Register
(
  input [4:0] read1,
  input [4:0] read2,
  output reg [63:0] data1,
  output reg [63:0] data2
);

  reg [63:0] Data[31:0];
  integer initCount;
  
  initial begin
    for (initCount = 0; initCount < 31; initCount = initCount + 1) begin
      Data[initCount] = initCount;
    end
	
    Data[31] = 64'h00000000;
  end
  
  always @(read1, read2) begin
    data1 = Data[read1];
    data2 = Data[read2];
  end
endmodule

module IC
(
  input [63:0] PC,
  output reg [31:0] Instruction
);
    
  reg [8:0] Data[63:0];
    
  initial begin

    // LDUR x2, [x10]
    Data[0] = 8'hF8;
    Data[1] = 8'h40;
    Data[2] = 8'h01;
    Data[3] = 8'h42;

    // LDUR x3, [x10, #1]
    Data[4] = 8'hF8;
    Data[5] = 8'h40;
    Data[6] = 8'h11;
    Data[7] = 8'h43;
    
    // SUB x4, x3, x2
    Data[8] = 8'hCB;
    Data[9] = 8'h02;
    Data[10] = 8'h00;
    Data[11] = 8'h64;

    // ADD x5, x3, x2
    Data[12] = 8'h8B;
    Data[13] = 8'h02;
    Data[14] = 8'h00;
    Data[15] = 8'h65;

    // CBZ x1, #2
    Data[16] = 8'hB4;
    Data[17] = 8'h00;
    Data[18] = 8'h00;
    Data[19] = 8'h41;

    // CBZ x0, #2
    Data[20] = 8'hB4;
    Data[21] = 8'h00;
    Data[22] = 8'h00;
    Data[23] = 8'h40;
	 
	 // LDUR x2 [x10]
    Data[24] = 8'hF8;
    Data[25] = 8'h40;
    Data[26] = 8'h01;
    Data[27] = 8'h42;

	 // ORR x6, x2, x3
    Data[28] = 8'hAA;
    Data[29] = 8'h03;
    Data[30] = 8'h00;
    Data[31] = 8'h46;

	 // AND x7, x2, x3
    Data[32] = 8'h8A;
    Data[33] = 8'h03;
    Data[34] = 8'h00;
    Data[35] = 8'h47;

    // STUR x4, [x7, #1]
    Data[36] = 8'hF8;
    Data[37] = 8'h00;
    Data[38] = 8'h10;
    Data[39] = 8'hE4;

	 // B #2
    Data[40] = 8'h14;
    Data[41] = 8'h00;
    Data[42] = 8'h00;
    Data[43] = 8'h03;

	 // LDUR x3, [x10, #1]
    Data[44] = 8'hF8;
    Data[45] = 8'h40;
    Data[46] = 8'h11;
    Data[47] = 8'h43;

	 // ADD x8, x0, x1
    Data[48] = 8'h8B;
    Data[49] = 8'h01;
    Data[50] = 8'h00;
    Data[51] = 8'h08;
  end
  
  always @(PC) begin
    Instruction[8:0] = Data[PC+3];
    Instruction[16:8] = Data[PC+2];
    Instruction[24:16] = Data[PC+1];
    Instruction[31:24] = Data[PC];
  end
endmodule

`timescale 1ns / 1ps

module SignExtend
(
  input [31:0] inputInstruction,
  output reg [63:0] outImmediate
);
  
    always @(inputInstruction) begin
      
      if (inputInstruction[31:26] == 6'b000101) begin // B
      
        outImmediate[25:0] <= inputInstruction[25:0];
        outImmediate[63:26] <= {64{outImmediate[25]}};
      
      end else if (inputInstruction[31:24] == 8'b10110100) begin // CBZ

        outImmediate[19:0] <= inputInstruction[23:5];
        outImmediate[63:20] <= {64{outImmediate[19]}};
        
      end else begin // D Type

        outImmediate[9:0] <= inputInstruction[20:12];
        outImmediate[63:10] <= {64{outImmediate[9]}};
      end
    end
  
endmodule

module Mux2
(
  input [4:0] read1,
  input [4:0] read2,
  input control_reg2loc,
  output reg [4:0] mux2reg_wire
);

  always @(read1, read2, control_reg2loc) begin
    
    case (control_reg2loc)
      

        
        1'b0 : begin
    mux2reg_wire <= read1;
        end
              1'b1 : begin
    mux2reg_wire <= read2;
        end
              default : begin
                mux2reg_wire <= 1'bx;
              end
    endcase
  end
  
endmodule

module Control
  (
    input [10:0] instruction,
    output reg control_reg2loc,
    output reg [1:0] control_aluop,
	output reg control_alusrc,
  	output reg control_isZeroBranch,
    output reg control_isUnconBranch,
  	output reg control_memRead,
 	output reg control_memwrite,
    output reg control_regwrite,
  	output reg control_mem2reg
  );
  
  always @(instruction) begin
    
    control_reg2loc <= 1'b1;
    
    /* B */
    if (instruction[10:5] == 6'b000101) begin // Control bits for B
      //$display("B");
      control_mem2reg <= 1'bx;
      control_memRead <= 1'b0;
      control_memwrite <= 1'b0;
      control_alusrc <= 1'b0;
      control_aluop <= 2'b01;
      control_isZeroBranch <= 1'b0;
      control_isUnconBranch <= 1'b1;
      control_regwrite <= 1'b0;
    end

    /* CBZ */
    else if (instruction[10:3] == 8'b10110100) begin // Control bits for CBZ
      //$display("CBZ");
      control_mem2reg <= 1'bx;
      control_memRead <= 1'b0;
      control_memwrite <= 1'b0;
      control_alusrc <= 1'b0;
      control_aluop <= 2'b01;
      control_isZeroBranch <= 1'b1;
      control_isUnconBranch <= 1'b0;
      control_regwrite <= 1'b0;
    end
    
    /* R-Type Instructions */
    else begin
      control_isZeroBranch <= 1'b0;
      control_isUnconBranch <= 1'b0;
      
      case (instruction[10:0])
        
        /* LDUR */
        11'b11111000010 : begin
          //$display("LDUR");
          control_mem2reg <= 1'b1;
          control_memRead <= 1'b1;
          control_memwrite <= 1'b0;
          control_alusrc <= 1'b1;
          control_aluop <= 2'b00;
          control_regwrite <= 1'b1;
          control_reg2loc <= 1'bx;
        end
        
        /* STUR */
        11'b11111000000 : begin
          //$display("STUR");
          control_mem2reg <= 1'bx;
          control_memRead <= 1'b0;
          control_memwrite <= 1'b1;
          control_alusrc <= 1'b1;
          control_aluop <= 2'b00;
          control_regwrite <= 1'b0;
        end
        
        /* ADD */
        11'b10001011000 : begin
          //$display("ADD");
          control_mem2reg <= 1'b0;
          control_memRead <= 1'b0;
          control_memwrite <= 1'b0;
          control_alusrc <= 1'b0;
          control_aluop <= 2'b10;
          control_regwrite <= 1'b1;
        end
        
        /* SUB */
        11'b11001011000 : begin
          //$display("SUB");
          control_mem2reg <= 1'b0;
          control_memRead <= 1'b0;
          control_memwrite <= 1'b0;
          control_alusrc <= 1'b0;
          control_aluop <= 2'b10;
          control_regwrite <= 1'b1;
        end
        
        /* AND */
        11'b10001010000 : begin
          //$display("AND");
          control_mem2reg <= 1'b0;
          control_memRead <= 1'b0;
          control_memwrite <= 1'b0;
          control_alusrc <= 1'b0;
          control_aluop <= 2'b10;
          control_regwrite <= 1'b1;
        end
        
        /* ORR */
        11'b10101010000 : begin
          //$display("ORR");
          control_mem2reg <= 1'b0;
          control_memRead <= 1'b0;
          control_memwrite <= 1'b0;
          control_alusrc <= 1'b0;
          control_aluop <= 2'b10;
          control_regwrite <= 1'b1;
        end
        
        default : begin
          control_isZeroBranch <= 1'bx;
      	  control_isUnconBranch <= 1'bx;
          control_mem2reg <= 1'bx;
          control_memRead <= 1'bx;
          control_memwrite <= 1'bx;
          control_alusrc <= 1'bx;
          control_aluop <= 2'bxx;
          control_regwrite <= 1'bx;
          control_reg2loc <= 1'bx;
        end
      endcase
    end
  end
  
endmodule