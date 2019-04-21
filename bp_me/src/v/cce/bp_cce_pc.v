/**
 *
 * Name:
 *   bp_cce_pc.v
 *
 * Description:
 *   PC register, next PC logic, and instruction memory
 *
 * Configuration Link
 *   The config link is used to fill the instruction RAM. At startup, reset_i and frozen_i will
 *   both be high. After reset_i goes low, this module waits for an external source to write
 *   the instruction RAM via the config link. The frozen_i signal is held high while the instruction
 *   RAM is written. After frozen_i goes low, the CCE begins normal operation.
 *
 *
 */

module bp_cce_pc
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter inst_ram_els_p             = "inv"

    // Config channel parameters
    , parameter cfg_link_addr_width_p = "inv"
    , parameter cfg_link_data_width_p = "inv"
    , parameter cfg_ram_base_addr_p   = "inv"

    // Default parameters
    , parameter harden_p                 = 0

    // Derived parameters
    , localparam inst_width_lp           = `bp_cce_inst_width
    , localparam inst_ram_addr_width_lp  = `BSG_SAFE_CLOG2(inst_ram_els_p)

    // number of bits in cfg data packet used for hi part write
    , localparam cfg_link_hi_data_width_lp = (inst_width_lp-cfg_link_data_width_p)
    , localparam cfg_link_hi_pad_width_lp = cfg_link_data_width_p-cfg_link_hi_data_width_lp
  )
  (input                                         clk_i
   , input                                       reset_i
   , input                                       freeze_i

   // Config channel
   , input [cfg_link_addr_width_p-2:0]           config_addr_i
   , input [cfg_link_data_width_p-1:0]           config_data_i
   , input                                       config_v_i
   , input                                       config_w_i
   , output logic                                config_ready_o

   , output logic [cfg_link_data_width_p-1:0]    config_data_o
   , output logic                                config_v_o
   , input                                       config_ready_i

   // ALU branch result signal
   , input                                       alu_branch_res_i

   // control from decode
   , input                                       pc_stall_i
   , input [inst_ram_addr_width_lp-1:0]          pc_branch_target_i

   // instruction output to decode
   , output logic [inst_width_lp-1:0]            inst_o
   , output logic                                inst_v_o
  );

  typedef enum logic [2:0] {
    RESET
    ,INIT
    ,INIT_END
    ,BOOT
    ,BOOT_END
    ,FETCH_1
    ,FETCH_2
    ,FETCH
  } pc_state_e;

  pc_state_e pc_state, pc_state_n;

  logic [inst_ram_addr_width_lp-1:0] ex_pc_r, ex_pc_n;
  logic inst_v_r, inst_v_n;
  logic ram_v_r, ram_v_n;
  logic ram_w_r, ram_w_n;
  logic [inst_ram_addr_width_lp-1:0] ram_addr_li, ram_addr_r, ram_addr_n;
  logic [inst_width_lp-1:0] ram_data_r, ram_data_n, ram_data_lo;
  logic [inst_width_lp-1:0] ram_w_mask_r, ram_w_mask_n;

  logic cfg_hi_not_lo_r, cfg_hi_not_lo_n;

  bsg_mem_1rw_sync_mask_write_bit
    #(.width_p(inst_width_lp)
      ,.els_p(inst_ram_els_p)
      )
    cce_inst_ram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(ram_v_r)
      ,.data_i(ram_data_r)
      ,.addr_i(ram_addr_li)
      ,.w_i(ram_w_r)
      ,.data_o(ram_data_lo)
      ,.w_mask_i(ram_w_mask_r)
      );

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      pc_state <= RESET;

      ex_pc_r <= '0;
      inst_v_r <= '0;
      ram_v_r <= '0;
      ram_w_r <= '0;
      ram_addr_r <= '0;
      ram_data_r <= '0;
      ram_w_mask_r <= '0;

      cfg_hi_not_lo_r <= '0;

    end else begin
      pc_state <= pc_state_n;

      ex_pc_r <= ex_pc_n;
      inst_v_r <= inst_v_n;
      ram_v_r <= ram_v_n;
      ram_w_r <= ram_w_n;
      ram_addr_r <= ram_addr_n;
      ram_data_r <= ram_data_n;
      ram_w_mask_r <= '0;

      cfg_hi_not_lo_r <= cfg_hi_not_lo_n;

    end
  end

  // config logic

  // is the inbound address for the lo or hi chunk of the instruction RAM?
  logic config_hi;
  assign config_hi = config_addr_i[0];

  always_comb begin
    // outputs always come from registers or the instruction RAM
    inst_v_o = inst_v_r;
    inst_o = ram_data_lo;

    // config link outputs default to 0
    config_ready_o = '0;
    config_v_o = '0;
    config_data_o = '0;

    // by default, regardless of the pc_state, send the instruction ram the registered value
    ram_addr_li = ram_addr_r;

    // next values for registers

    // defaults
    pc_state_n = RESET;
    ex_pc_n = '0;
    inst_v_n = '0;
    ram_v_n = '0;
    ram_w_n = '0;
    ram_addr_n = ram_addr_r;
    ram_data_n = '0;
    ram_w_mask_n = '0;
    cfg_hi_not_lo_n = cfg_hi_not_lo_r;

    case (pc_state)
      RESET: begin
        pc_state_n = (reset_i) ? RESET : INIT;
      end
      INIT: begin
        config_ready_o = 1'b1;
        if (config_v_i) begin
          // inputs to RAM are valid if config address high bit is set
          ram_v_n = config_v_i & config_addr_i[cfg_link_addr_width_p-2];
          ram_w_n = config_w_i;
          // lsb of config address specifies if write is first or second part, so ram addr
          // starts at bit 1
          ram_addr_n = config_addr_i[1+:inst_ram_addr_width_lp];
          cfg_hi_not_lo_n = config_hi;
          if (config_hi) begin
            ram_w_mask_n = {(cfg_link_hi_data_width_lp)'('1),(cfg_link_data_width_p)'('0)};
            ram_data_n = {config_data_i[0+:cfg_link_hi_data_width_lp],(cfg_link_data_width_p)'('0)};
          end else begin
            ram_w_mask_n = {(cfg_link_hi_data_width_lp)'('0),(cfg_link_data_width_p)'('1)};
            ram_data_n = {(cfg_link_hi_data_width_lp)'('0),config_data_i};
          end
          pc_state_n = (ram_v_n & ram_w_n) ? INIT
                       : (ram_v_n) ? INIT_RD_RESP : INIT;
        end else begin
          pc_state_n = (~frozen_i) ? INIT_END : INIT;
        end
      end
      INIT_RD_RESP: begin
        // hold the read valid until cfg link accepts the outbound packet
        ram_v_n = ~config_ready_i;
        ram_addr_n = ram_addr_r;
        config_v_o = 1'b1;
        config_data_o = (cfg_hi_not_lo_r)
          ? {(cfg_link_hi_pad_width_lp)'('0),ram_data_lo[0+:cfg_link_hi_data_width_lp]}
          : ram_data_lo[0+:cfg_link_data_width_p];
        pc_state_n = (config_ready_i) ? INIT : INIT_RD_RESP;
      end
      INIT_END: begin
        // let the last cfg link write finish
        pc_state_n = FETCH_1;
      end
      FETCH_1: begin
        // At the end of this cycle, the RAM will write the last instruction from the boot ROM
        // into its memory array. The following cycle, PC will be setup to start fetching from
        // address 0

        // setup to fetch first instruction
        // at end of cycle 1, RAM controls are captured into registers
        // at end of cycle 2, RAM captures the registers
        // in cycle 3, the instruction is produced and executed
        pc_state_n = FETCH_2;

        // setup input registers for instruction RAM
        // fetch address 0
        ram_v_n = 1'b1;
        ram_addr_n = '0;

        ex_pc_n = '0;
        inst_v_n = '0;

      end
      FETCH_2: begin
        // setup the registers for the first instruction
        pc_state_n = FETCH;

        ram_v_n = 1'b1;
        ram_addr_n = ram_addr_r + 'd1;

        // at the end of this cycle, inputs to the instruction RAM will be latched into the
        // registers that feed the RAM inputs

        // Thus, next cycle, no instruction will be valid
        ex_pc_n = '0;
        inst_v_n = '0;

      end
      FETCH: begin
        // Always continue fetching instructions
        pc_state_n = FETCH;
        // next instruction is always valid once in steady state
        inst_v_n = 1'b1;

        // Always fetch an instruction
        ram_v_n = 1'b1;
        // setup RAM address register and register tracking PC of instruction being executed
        // also, determine input address for RAM depending on stall and branch in execution
        if (pc_stall_i) begin
          // when stalling, hold executing pc and ram addr registers constant
          ex_pc_n = ex_pc_r;
          ram_addr_n = ram_addr_r;
          // feed the currently executing pc as input to instruction ram
          ram_addr_li = ex_pc_r;
        end else if (alu_branch_res_i) begin
          // when branching, the instruction executed next is the branch target
          ex_pc_n = pc_branch_target_i;
          // the following instruction to fetch is after the branch target
          ram_addr_n = pc_branch_target_i + 'd1;
          // if branching, use the branch target from the current instruction
          ram_addr_li = pc_branch_target_i;
        end else begin
          // normal execution, the instruction that will be executed is the one that will
          // be fetched in sequential order
          ex_pc_n = ram_addr_r;
          // the next instruction to fetch follows sequentially
          ram_addr_n = ram_addr_r + 'd1;
          // normally, use the address register (i.e., sequential execution)
          ram_addr_li = ram_addr_r;
        end

      end
    endcase
  end

endmodule
