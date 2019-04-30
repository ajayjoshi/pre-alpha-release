/**
 *
 * bp_tile.v
 *
 */

module bp_tile
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )

   , localparam proc_cfg_width_lp = `bp_proc_cfg_width(num_core_p, num_lce_p)

   , localparam dirs_lp = 4 // S (Mem side) EW (LCE sides), P (Proc side)

   // Used to enable trace replay outputs for testbench
   , parameter trace_p      = 0
   , parameter calc_debug_p = 1
   , parameter debug_p      = 0 // Debug for the network (TODO: rename)
   )
  (input                                                      clk_i
   , input                                                    reset_i

   , input [proc_cfg_width_lp-1:0]                            proc_cfg_i

   // This will go away with the manycore bridge
   , output [`BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)-1:0] cce_inst_boot_rom_addr_o
   , input [`bp_cce_inst_width-1:0]                        cce_inst_boot_rom_data_i

   // Router - Outputs
   , output [1:0][lce_cce_req_width_lp-1:0]       lce_req_o
   , output [1:0]                                 lce_req_v_o
   , input [1:0]                                  lce_req_ready_i

   , output [1:0][lce_cce_resp_width_lp-1:0]      lce_resp_o
   , output [1:0]                                 lce_resp_v_o
   , input [1:0]                                  lce_resp_ready_i

   , output [1:0][lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
   , output [1:0]                                 lce_data_resp_v_o
   , input [1:0]                                  lce_data_resp_ready_i

   , input [1:0][cce_lce_cmd_width_lp-1:0]        lce_cmd_i
   , input [1:0]                                  lce_cmd_v_i
   , output [1:0]                                 lce_cmd_ready_o

   , input [1:0][lce_data_cmd_width_lp-1:0]       lce_data_cmd_i
   , input [1:0]                                  lce_data_cmd_v_i
   , output [1:0]                                 lce_data_cmd_ready_o

   // Router - Inputs 
   , input [1:0][lce_cce_req_width_lp-1:0]       lce_req_i
   , input [1:0]                                 lce_req_v_i
   , output [1:0]                                  lce_req_ready_o

   , input [1:0][lce_cce_resp_width_lp-1:0]      lce_resp_i
   , input [1:0]                                 lce_resp_v_i
   , output [1:0]                                  lce_resp_ready_o

   , input [1:0][lce_cce_data_resp_width_lp-1:0] lce_data_resp_i
   , input [1:0]                                 lce_data_resp_v_i
   , output [1:0]                                  lce_data_resp_ready_o

   , output [1:0][cce_lce_cmd_width_lp-1:0]        lce_cmd_o
   , output [1:0]                                  lce_cmd_v_o
   , input [1:0]                                 lce_cmd_ready_i

   , output [1:0][lce_data_cmd_width_lp-1:0]       lce_data_cmd_o
   , output [1:0]                                  lce_data_cmd_v_o
   , input [1:0]                                 lce_data_cmd_ready_i

   // Memory side connection
   , input [mem_cce_resp_width_lp-1:0]         mem_resp_i
   , input                                     mem_resp_v_i
   , output                                    mem_resp_ready_o

   , input [mem_cce_data_resp_width_lp-1:0]    mem_data_resp_i
   , input                                     mem_data_resp_v_i
   , output                                    mem_data_resp_ready_o

   , output [cce_mem_cmd_width_lp-1:0]         mem_cmd_o
   , output                                    mem_cmd_v_o
   , input                                     mem_cmd_yumi_i

   , output [cce_mem_data_cmd_width_lp-1:0]    mem_data_cmd_o
   , output                                    mem_data_cmd_v_o
   , input                                     mem_data_cmd_yumi_i

   // Interrupts
   , input                                     timer_int_i
   , input                                     software_int_i
   , input                                     external_int_i

   // Commit tracer for trace replay
   // TODO: Remove
   , output                                   cmt_rd_w_v_o
   , output [rv64_reg_addr_width_gp-1:0]      cmt_rd_addr_o
   , output                                   cmt_mem_w_v_o
   , output [dword_width_p-1:0]               cmt_mem_addr_o
   , output [`bp_be_fu_op_width-1:0]          cmt_mem_op_o
   , output [dword_width_p-1:0]               cmt_data_o
  );

`declare_bp_common_proc_cfg_s(num_core_p, num_lce_p)
`declare_bp_lce_cce_if(num_cce_p
                       ,num_lce_p
                       ,paddr_width_p
                       ,lce_assoc_p
                       ,dword_width_p
                       ,cce_block_width_p
                       )

// Proc-side connections network connections
bp_lce_cce_req_s [1:0] lce_req_lo;
logic [1:0] lce_req_v_lo, lce_req_ready_li;

bp_lce_cce_resp_s [1:0] lce_resp_lo;
logic [1:0] lce_resp_v_lo, lce_resp_ready_li;

bp_lce_cce_data_resp_s [1:0] lce_data_resp_lo;
logic [1:0] lce_data_resp_v_lo, lce_data_resp_ready_li;

bp_cce_lce_cmd_s [1:0] lce_cmd_li;
logic [1:0] lce_cmd_v_li, lce_cmd_ready_lo;

bp_lce_data_cmd_s [1:0] lce_data_cmd_li;
logic [1:0] lce_data_cmd_v_li, lce_data_cmd_ready_lo;

bp_lce_data_cmd_s [1:0] lce_data_cmd_lo;
logic [1:0] lce_data_cmd_v_lo, lce_data_cmd_ready_li;

bp_proc_cfg_s proc_cfg_cast_i;
assign proc_cfg_cast_i = proc_cfg_i;

// Module instantiations
bp_core   
 #(.cfg_p(cfg_p)
   ,.trace_p(trace_p)
   ,.calc_debug_p(calc_debug_p)
   )
 core 
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.proc_cfg_i(proc_cfg_i)

   ,.lce_req_o(lce_req_lo)
   ,.lce_req_v_o(lce_req_v_lo)
   ,.lce_req_ready_i(lce_req_ready_li)

   ,.lce_resp_o(lce_resp_lo)
   ,.lce_resp_v_o(lce_resp_v_lo)
   ,.lce_resp_ready_i(lce_resp_ready_li)

   ,.lce_data_resp_o(lce_data_resp_lo)
   ,.lce_data_resp_v_o(lce_data_resp_v_lo)
   ,.lce_data_resp_ready_i(lce_data_resp_ready_li)

   ,.lce_cmd_i(lce_cmd_li)
   ,.lce_cmd_v_i(lce_cmd_v_li)
   ,.lce_cmd_ready_o(lce_cmd_ready_lo)

   ,.lce_data_cmd_i(lce_data_cmd_li)
   ,.lce_data_cmd_v_i(lce_data_cmd_v_li)
   ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo)

   ,.lce_data_cmd_o(lce_data_cmd_lo)
   ,.lce_data_cmd_v_o(lce_data_cmd_v_lo)
   ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li)

   ,.timer_int_i(timer_int_i)
   ,.software_int_i(software_int_i)
   ,.external_int_i(external_int_i)

   ,.cmt_rd_w_v_o(cmt_rd_w_v_o)
   ,.cmt_rd_addr_o(cmt_rd_addr_o)
   ,.cmt_mem_w_v_o(cmt_mem_w_v_o)
   ,.cmt_mem_addr_o(cmt_mem_addr_o)
   ,.cmt_mem_op_o(cmt_mem_op_o)
   ,.cmt_data_o(cmt_data_o)
   );

bp_tile_router
 #(.cfg_p(cfg_p)
   ,.x_coord_width_p(`BSG_SAFE_CLOG2(num_lce_p))
   ,.y_coord_width_p(1)
   )
 icache_tile_router
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.my_x_i(proc_cfg.icache_id)
   ,.my_y_i(1)
   );

bp_tile_router
 #(.cfg_p(cfg_p)
   ,.x_coord_width_p(`BSG_SAFE_CLOG2(num_lce_p))
   ,.y_coord_width_p(1)
   )
 dcache_tile_router
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.my_x_i(proc_cfg.dcache_id)
   ,.my_y_i(1)
   );

bp_cce_top
 #(.num_lce_p(num_lce_p)
   ,.num_cce_p(num_cce_p)
   ,.paddr_width_p(paddr_width_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.lce_sets_p(lce_sets_p)
   ,.block_size_in_bytes_p(cce_block_width_p/8)
   ,.num_cce_inst_ram_els_p(num_cce_instr_ram_els_p)
   ,.lce_req_data_width_p(dword_width_p)
   ,.cfg_link_addr_width_p(16) // TODO: move these into proc cfg?
   ,.cfg_link_data_width_p(32)
   ,.cce_trace_p(0)
   )
 cce
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.freeze_i(1'b0)
   ,.config_addr_i('0)
   ,.config_data_i('0)
   ,.config_v_i('0)
   ,.config_w_i('0)
   ,.config_ready_o()

   ,.config_data_o()
   ,.config_v_o()
   ,.config_ready_i('0)

   ,.boot_rom_addr_o(cce_inst_boot_rom_addr_o)
   ,.boot_rom_data_i(cce_inst_boot_rom_data_i)

   // To CCE
   ,.lce_req_i()
   ,.lce_req_v_i()
   ,.lce_req_ready_o()

   ,.lce_resp_i()
   ,.lce_resp_v_i()
   ,.lce_resp_ready_o()

   ,.lce_data_resp_i()
   ,.lce_data_resp_v_i()
   ,.lce_data_resp_ready_o()

   // From CCE
   ,.lce_cmd_o()
   ,.lce_cmd_v_o()
   ,.lce_cmd_ready_i()

   ,.lce_data_cmd_o()
   ,.lce_data_cmd_v_o()
   ,.lce_data_cmd_ready_i()

   // To CCE
   ,.mem_resp_i(mem_resp_i)
   ,.mem_resp_v_i(mem_resp_v_i)
   ,.mem_resp_ready_o(mem_resp_ready_o)
   ,.mem_data_resp_i(mem_data_resp_i)
   ,.mem_data_resp_v_i(mem_data_resp_v_i)
   ,.mem_data_resp_ready_o(mem_data_resp_ready_o)

   // From CCE
   ,.mem_cmd_o(mem_cmd_o)
   ,.mem_cmd_v_o(mem_cmd_v_o)
   ,.mem_cmd_yumi_i(mem_cmd_yumi_i)
   ,.mem_data_cmd_o(mem_data_cmd_o)
   ,.mem_data_cmd_v_o(mem_data_cmd_v_o)
   ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_i)
   );
   

endmodule : bp_tile

