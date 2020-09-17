/**
 * Module: KeccakF400Round
 *
 * Implements one round of the Keccakf400 permutation. The SystemVerilog
 * implementation is based on the VHDL implementation given on the project
 * page: http://keccak.noekeon.org/files.html
 *
 *
 * General Information:
 * File         - keccakf400_round.sv
 * Title        - Keccakf400 round function
 * Project      - Secure PULP
 * Author       - Robert Schilling (rschilling@student.tugraz.at)
 * Company      - Integrated Systems Laboratory - ETH Zurich,
 *                Institute of Applied Information Processing and
                  Communications - TU Graz
 * Copyright    - Copyright 2015 Integrated Systems Laboratory - ETH Zurich,
                  Institute of Applied Information Processing and
                  Communications - TU Graz
 * File Created - 2015-09-18
 * Last Updated - 2015-09-18
 * Platform     - Simulation=QuestaSim; Synthesis=Synopsys
 * Standard     - SystemVerilog 1800-2009
 *
 *
 * Major Revisions:
 * 2015-09-18 (v1.0) - Created (rs)
 */

import keccak_pkg::*;

module KeccakP400Round (
  input [400-1:0] inp_di,
  input [4:0] round_di,
  output [400-1:0] outp_do
);

//assign outp_do = {inp_di[0], inp_di[319:1]}^round_dii;

  k_state ThetaInp_D, ThetaOutp_D, PiInp_D, PiOutp_D, RhoInp_D, RhoOutp_D,
          ChiInp_D, ChiOutp_D, IoataInp_D, IoataOutp_D;
  k_plane sum_sheet;
  
  const logic [15:0] RC[20]= '{ 16'h0001, 16'h8082, 16'h808A, 16'h8000, 16'h808B, 16'h0001, 
                                16'h8081, 16'h8009, 16'h008A, 16'h0088, 16'h8009, 16'h000A,
                                16'h808B, 16'h008B, 16'h8089, 16'h8003, 16'h8002, 16'h0080, 
                                16'h800A, 16'h000A};

  genvar y,x,i;

  // Order is theta, pi, rho, chi, iota
  assign ThetaInp_D = to_keccak_state(inp_di);
  assign RhoInp_D   = ThetaOutp_D;
  assign PiInp_D    = RhoOutp_D;
  assign ChiInp_D   = PiOutp_D;
  assign IoataInp_D = ChiOutp_D;
  assign outp_do    = to_keccak_logic(IoataOutp_D);

  //----------------------------------------------------------------------------
  // THETA
  //----------------------------------------------------------------------------

  generate
    for(x = 0; x < 5; x++)
      for(i = 0; i < N; i++)
        assign sum_sheet[x][i] = ThetaInp_D[x][0][i] ^ ThetaInp_D[x][1][i] ^ ThetaInp_D[x][2][i] ^ ThetaInp_D[x][3][i] ^ ThetaInp_D[x][4][i];
  endgenerate

  generate
    for(y = 0; y < 5; y++)
      for(x = 1; x < 4; x++) begin
        assign ThetaOutp_D[x][y][0] = ThetaInp_D[x][y][0] ^ sum_sheet[x-1][0] ^ sum_sheet[x+1][N-1];
        for(i = 1; i < N; i++)
          assign ThetaOutp_D[x][y][i] = ThetaInp_D[x][y][i] ^ sum_sheet[x-1][i] ^ sum_sheet[x+1][i-1];
      end
  endgenerate

  generate
    for(y = 0; y < 5; y++) begin
      assign ThetaOutp_D[0][y][0] = ThetaInp_D[0][y][0] ^ sum_sheet[4][0] ^ sum_sheet[1][N-1];
      for(i = 1; i < N; i++)
        assign ThetaOutp_D[0][y][i] = ThetaInp_D[0][y][i] ^ sum_sheet[4][i] ^ sum_sheet[1][i-1];
    end
  endgenerate

  generate
    for(y = 0; y < 5; y++) begin
      assign ThetaOutp_D[4][y][0] = ThetaInp_D[4][y][0] ^ sum_sheet[3][0] ^ sum_sheet[0][N-1];
      for(i = 1; i < N; i++)
        assign ThetaOutp_D[4][y][i] = ThetaInp_D[4][y][i] ^ sum_sheet[3][i] ^ sum_sheet[0][i-1];
    end
  endgenerate

  //----------------------------------------------------------------------------
  // RHO
  //----------------------------------------------------------------------------

  generate
    for(i = 0; i < N; i++) begin
      assign RhoOutp_D[0][0][i] = RhoInp_D[0][0][i];
      assign RhoOutp_D[1][0][i] = RhoInp_D[1][0][NEG_MOD(i-1) ];
      assign RhoOutp_D[2][0][i] = RhoInp_D[2][0][NEG_MOD(i-62)];
      assign RhoOutp_D[3][0][i] = RhoInp_D[3][0][NEG_MOD(i-28)];
      assign RhoOutp_D[4][0][i] = RhoInp_D[4][0][NEG_MOD(i-27)];
      assign RhoOutp_D[0][1][i] = RhoInp_D[0][1][NEG_MOD(i-36)];
      assign RhoOutp_D[1][1][i] = RhoInp_D[1][1][NEG_MOD(i-44)];
      assign RhoOutp_D[2][1][i] = RhoInp_D[2][1][NEG_MOD(i-6) ];
      assign RhoOutp_D[3][1][i] = RhoInp_D[3][1][NEG_MOD(i-55)];
      assign RhoOutp_D[4][1][i] = RhoInp_D[4][1][NEG_MOD(i-20)];
      assign RhoOutp_D[0][2][i] = RhoInp_D[0][2][NEG_MOD(i-3) ];
      assign RhoOutp_D[1][2][i] = RhoInp_D[1][2][NEG_MOD(i-10)];
      assign RhoOutp_D[2][2][i] = RhoInp_D[2][2][NEG_MOD(i-43)];
      assign RhoOutp_D[3][2][i] = RhoInp_D[3][2][NEG_MOD(i-25)];
      assign RhoOutp_D[4][2][i] = RhoInp_D[4][2][NEG_MOD(i-39)];
      assign RhoOutp_D[0][3][i] = RhoInp_D[0][3][NEG_MOD(i-41)];
      assign RhoOutp_D[1][3][i] = RhoInp_D[1][3][NEG_MOD(i-45)];
      assign RhoOutp_D[2][3][i] = RhoInp_D[2][3][NEG_MOD(i-15)];
      assign RhoOutp_D[3][3][i] = RhoInp_D[3][3][NEG_MOD(i-21)];
      assign RhoOutp_D[4][3][i] = RhoInp_D[4][3][NEG_MOD(i-8) ];
      assign RhoOutp_D[0][4][i] = RhoInp_D[0][4][NEG_MOD(i-18)];
      assign RhoOutp_D[1][4][i] = RhoInp_D[1][4][NEG_MOD(i-2) ];
      assign RhoOutp_D[2][4][i] = RhoInp_D[2][4][NEG_MOD(i-61)];
      assign RhoOutp_D[3][4][i] = RhoInp_D[3][4][NEG_MOD(i-56)];
      assign RhoOutp_D[4][4][i] = RhoInp_D[4][4][NEG_MOD(i-14)];
    end
  endgenerate


  //----------------------------------------------------------------------------
  // PI
  //----------------------------------------------------------------------------

  generate
    for(y = 0; y < 5; y++)
      for(x = 0; x < 5; x++)
        for(i = 0; i < N; i++)
          assign PiOutp_D[y][(2*x+3*y) % 5][i] = PiInp_D[x][y][i];
  endgenerate


  //----------------------------------------------------------------------------
  // CHI
  //----------------------------------------------------------------------------

  generate
    for(y = 0; y < 5; y++)
      for(x = 0; x < 3; x++)
        for(i = 0; i < N; i++)
          assign ChiOutp_D[x][y][i] = ChiInp_D[x][y][i] ^ (~(ChiInp_D[x+1][y][i]) & ChiInp_D[x+2][y][i]);
  endgenerate

  generate
    for(y = 0; y < 5; y++)
      for(i = 0; i < N; i++)
        assign ChiOutp_D[3][y][i] = ChiInp_D[3][y][i] ^ (~(ChiInp_D[4][y][i]) & ChiInp_D[0][y][i]);
  endgenerate

  generate
    for(y = 0; y < 5; y++)
      for(i = 0; i < N; i++)
        assign ChiOutp_D[4][y][i] = ChiInp_D[4][y][i] ^ (~(ChiInp_D[0][y][i]) & ChiInp_D[1][y][i]);
  endgenerate

  //----------------------------------------------------------------------------
  // IOTA
  //----------------------------------------------------------------------------

  generate
    for(y = 1; y < 5; y++)
      for(x = 0; x < 5; x++)
        for(i = 0; i < N; i++)
          assign IoataOutp_D[x][y][i] = IoataInp_D[x][y][i];
  endgenerate

  generate
    for(x = 1; x < 5; x++)
      for(i = 0; i < N; i++)
        assign IoataOutp_D[x][0][i] = IoataInp_D[x][0][i];
  endgenerate

  generate
    for(i = 0; i < N; i++)
      assign IoataOutp_D[0][0][i] = IoataInp_D[0][0][i] ^ RC[20-round_di][i];
  endgenerate

endmodule