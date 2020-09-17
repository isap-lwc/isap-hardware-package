/**
 * Package: keccak_pkg
 *
 * Defines parameters, types and conversion functions for the Keccakf400
 * permutation implementation.
 *
 *
 * General Information:
 * File         - keccak_pkg.sv
 * Title        - Parameters, types and helper functions for Keccak
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

package keccak_pkg;

  parameter int unsigned N          = 16;
  parameter int unsigned STATE_SIZE = 5 * 5 * N;

  typedef logic [4:0][N-1:0] k_plane;
  typedef k_plane [4:0]      k_state;

  // --------------------------------------------------------------------------
  // Functions
  // --------------------------------------------------------------------------

  /**
   * Function: to_state
   * Converts a logic[STATE_SIZE-1:0] to the internal state.
   */
  function automatic k_state to_keccak_state(logic [STATE_SIZE-1:0] inp);
    k_state state;
    int x, y, z;

    for(x = 0; x < 5; x++) begin
      for(y = 0; y < 5; y++) begin
        for(z = 0; z < N; z++) begin
          state[x][y][z] = inp[(N*(5*y + x) + z)];
        end
      end
    end
    return state;
  endfunction

  /**
   * Function: to_logic
   * Converts a state to a logic[STATE_SIZE-1:0].
   */
  function automatic logic[STATE_SIZE-1:0] to_keccak_logic(k_state state);
    logic [STATE_SIZE-1:0] result;
    int x, y, z;

    for(x = 0; x < 5; x++) begin
      for(y = 0; y < 5; y++) begin
        for(z = 0; z < N; z++) begin
          result[(N*(5*y + x) + z)] = state[x][y][z];
        end
      end
    end
    return result;
  endfunction

  function automatic int NEG_MOD(int n);
    int unsigned m = n;
    return m % N;
  endfunction

endpackage
