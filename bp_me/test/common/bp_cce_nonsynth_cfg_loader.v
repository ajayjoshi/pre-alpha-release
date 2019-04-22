/**
 *
 * Name:
 *   bp_cce_nonsysnth_cfg_loader.v
 *
 * Description:
 *
 */ 

module bp_cce_nonsynth_cfg_loader
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  #(parameter inst_width_p            = "inv"
    , parameter inst_ram_addr_width_p = "inv"
    , parameter cfg_link_addr_width_p = "inv"
    , parameter cfg_link_data_width_p = "inv"
    , parameter inst_ram_els_p        = "inv"
    , localparam cfg_writes_lp = (2*inst_ram_els_p)
    , localparam data_hi_width_lp = (inst_width_p-cfg_link_data_width_p)
    , localparam data_hi_pad_lp = (cfg_link_data_width_p-data_hi_width_lp)
  )
  (input                                             clk_i
   , input                                           reset_i
   , output logic                                    freeze_o

   , output logic [inst_ram_addr_width_p-1:0]        boot_rom_addr_o
   , input [inst_width_p-1:0]                        boot_rom_data_i

   // Config channel
   , output logic [cfg_link_addr_width_p-2:0]        config_addr_o
   , output logic [cfg_link_data_width_p-1:0]        config_data_o
   , output logic                                    config_v_o
   , output logic                                    config_w_o
   , input                                           config_ready_i

   , input [cfg_link_data_width_p-1:0]               config_data_i
   , input                                           config_v_i
   , output logic                                    config_ready_o

  );

  // TODO: reads if we want
  wire unused1;
  assign unused1 = config_v_i;
  wire [cfg_link_data_width_p-1:0] unused2;
  assign unused2 = config_data_i;

  typedef enum logic [2:0] {
    RESET
    ,PAUSE
    ,SEND
    ,DONE
  } cfg_state_e;

  cfg_state_e state, state_n;

  logic [cfg_link_addr_width_p-2:0] cfg_addr_r, cfg_addr_n;
  logic freeze_r, freeze_n;
  assign freeze_o = freeze_r;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state <= RESET;
      cfg_addr_r <= {1'b1, (cfg_link_addr_width_p-2)'('0)};
      freeze_r <= 1'b1;
    end else begin
      state <= state_n;
      cfg_addr_r <= cfg_addr_n;
      freeze_r <= freeze_n;
    end
  end

  logic cfg_hi;
  assign cfg_hi = cfg_addr_r[0];
  assign boot_rom_addr_o = cfg_addr_r[1+:inst_ram_addr_width_p];

  always_comb begin
    if (reset_i) begin
      freeze_n = 1'b1;
      cfg_addr_n = {1'b1, (cfg_link_addr_width_p-2)'('0)};
      state_n = RESET;
      config_v_o = '0;
      config_w_o = '0;
      config_addr_o = '0;
      config_data_o = '0;
      config_ready_o = '0;

    end else begin
      freeze_n = 1'b1;
      cfg_addr_n = cfg_addr_r;
      state_n = state;
      config_v_o = '0;
      config_w_o = '0;
      config_addr_o = '0;
      config_data_o = '0;
      config_ready_o = '0;

      case (state)
        RESET: begin
          state_n = (reset_i) ? RESET : PAUSE;
        end
        PAUSE: begin
          state_n = SEND;
        end
        SEND: begin
          config_v_o = 1'b1;
          config_w_o = 1'b1;
          config_addr_o = cfg_addr_r;
          config_data_o = (cfg_hi)
            ? {(data_hi_pad_lp)'('0),boot_rom_data_i[cfg_link_data_width_p+:data_hi_width_lp]}
            : boot_rom_data_i[0+:cfg_link_data_width_p];
          if (config_ready_i) begin
            cfg_addr_n = cfg_addr_r + 'd1;
            state_n = (cfg_addr_r[0+:(inst_ram_addr_width_p+1)] == (cfg_writes_lp-1)) ? DONE : SEND;
            freeze_n = (cfg_addr_r[0+:(inst_ram_addr_width_p+1)] == (cfg_writes_lp-1)) ? 1'b0 : 1'b1;
          end else begin
            state_n = SEND;
          end
        end
        DONE: begin
          freeze_n = '0;
          state_n = DONE;
        end
      endcase
    end
  end

endmodule
