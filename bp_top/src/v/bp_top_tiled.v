/**
 *
 * bp_top_tiled.v
 *
 */

module bp_top_tiled
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
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

   // Used to enable trace replay outputs for testbench
   , parameter trace_p      = 0
   , parameter calc_debug_p = 1

   , parameter x_cord_width_p = `BSG_SAFE_CLOG2(num_lce_p)
   , parameter y_cord_width_p = 1

   , localparam lce_cce_req_network_width_lp = lce_cce_req_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1
   , localparam lce_cce_resp_network_width_lp = lce_cce_resp_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1
   , localparam cce_lce_cmd_network_width_lp = cce_lce_cmd_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1
   , localparam lce_cce_data_resp_network_width_lp = lce_cce_data_resp_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1
   , localparam lce_data_cmd_network_width_lp = lce_data_cmd_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1
   )
  (input                                                      clk_i
   , input                                                    reset_i

   // This will go away with the manycore bridge
   , output logic [num_cce_p-1:0][`BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)-1:0] cce_inst_boot_rom_addr_o
   , input logic [num_cce_p-1:0][`bp_cce_inst_width-1:0]                        cce_inst_boot_rom_data_i

   , input [num_cce_p-1:0][mem_cce_resp_width_lp-1:0]         mem_resp_i
   , input [num_cce_p-1:0]                                    mem_resp_v_i
   , output [num_cce_p-1:0]                                   mem_resp_ready_o

   , input [num_cce_p-1:0][mem_cce_data_resp_width_lp-1:0]    mem_data_resp_i
   , input [num_cce_p-1:0]                                    mem_data_resp_v_i
   , output [num_cce_p-1:0]                                   mem_data_resp_ready_o

   , output [num_cce_p-1:0][cce_mem_cmd_width_lp-1:0]         mem_cmd_o
   , output [num_cce_p-1:0]                                   mem_cmd_v_o
   , input [num_cce_p-1:0]                                    mem_cmd_yumi_i

   , output [num_cce_p-1:0][cce_mem_data_cmd_width_lp-1:0]    mem_data_cmd_o
   , output [num_cce_p-1:0]                                   mem_data_cmd_v_o
   , input [num_cce_p-1:0]                                    mem_data_cmd_yumi_i

   , input                                                    timer_int_i
   , input                                                    software_int_i
   , input                                                    external_int_i

   // Commit tracer for trace replay
   , output [num_core_p-1:0]                                  cmt_rd_w_v_o
   , output [num_core_p-1:0][rv64_reg_addr_width_gp-1:0]      cmt_rd_addr_o
   , output [num_core_p-1:0]                                  cmt_mem_w_v_o
   , output [num_core_p-1:0][dword_width_p-1:0]               cmt_mem_addr_o
   , output [num_core_p-1:0][`bp_be_fu_op_width-1:0]          cmt_mem_op_o
   , output [num_core_p-1:0][dword_width_p-1:0]               cmt_data_o
  );

`declare_bp_common_proc_cfg_s(num_core_p, num_lce_p)
`declare_bp_lce_cce_if(num_cce_p
                       ,num_lce_p
                       ,paddr_width_p
                       ,lce_assoc_p
                       ,dword_width_p
                       ,cce_block_width_p
                       )

logic [num_core_p:0][E:W][2+lce_cce_req_network_width_lp-1:0] lce_req_link_stitch_lo, lce_req_link_stitch_li;
logic [num_core_p:0][E:W][2+lce_cce_resp_network_width_lp-1:0] lce_resp_link_stitch_lo, lce_resp_link_stitch_li;
logic [num_core_p:0][E:W][2+lce_cce_data_resp_network_width_lp-1:0] lce_data_resp_link_stitch_lo, lce_data_resp_link_stitch_li;
logic [num_core_p:0][E:W][2+cce_lce_cmd_network_width_lp-1:0] lce_cmd_link_stitch_lo, lce_cmd_link_stitch_li;
logic [num_core_p:0][E:W][2+lce_data_cmd_network_width_lp-1:0] lce_data_cmd_link_stitch_lo, lce_data_cmd_link_stitch_li;

for(genvar i = 0; i < num_core_p; i++) 
  begin : rof1
    localparam mhartid   = i;
    localparam icache_id = (i * 2 + 0);
    localparam dcache_id = (i * 2 + 1);

    localparam mhartid_width_lp = `BSG_SAFE_CLOG2(num_core_p);
    localparam lce_id_width_lp  = `BSG_SAFE_CLOG2(num_lce_p);

    bp_proc_cfg_s proc_cfg;
    assign proc_cfg.mhartid   = mhartid[0+:mhartid_width_lp];
    assign proc_cfg.icache_id = icache_id[0+:lce_id_width_lp];
    assign proc_cfg.dcache_id = dcache_id[0+:lce_id_width_lp];

    if (i > 0)
      begin
        assign lce_req_link_stitch_li[i][W] = lce_req_link_stitch_lo[i-1][E];
        assign lce_resp_link_stitch_li[i][W] = lce_resp_link_stitch_lo[i-1][E];
        assign lce_data_resp_link_stitch_li[i][W] = lce_data_resp_link_stitch_lo[i-1][E];
        assign lce_cmd_link_stitch_li[i][W] = lce_cmd_link_stitch_lo[i-1][E];
        assign lce_data_cmd_link_stitch_li[i][W] = lce_data_cmd_link_stitch_lo[i-1][E];
      end
    else  
      begin
        assign lce_req_link_stitch_li[i][W] = '0;
        assign lce_resp_link_stitch_li[i][W] = '0;
        assign lce_data_resp_link_stitch_li[i][W] = '0;
        assign lce_cmd_link_stitch_li[i][W] = '0;
        assign lce_data_cmd_link_stitch_li[i][W] = '0;
      end

    if (i < num_core_p-1)
      begin
        assign lce_req_link_stitch_li[i][E] = lce_req_link_stitch_lo[i+1][W];
        assign lce_resp_link_stitch_li[i][E] = lce_resp_link_stitch_lo[i+1][W];
        assign lce_data_resp_link_stitch_li[i][E] = lce_data_resp_link_stitch_lo[i+1][W];
        assign lce_cmd_link_stitch_li[i][E] = lce_cmd_link_stitch_lo[i+1][W];
        assign lce_data_cmd_link_stitch_li[i][E] = lce_data_cmd_link_stitch_lo[i+1][W];
      end
    else
      begin
        assign lce_req_link_stitch_li[i][E] = '0;
        assign lce_resp_link_stitch_li[i][E] = '0;
        assign lce_data_resp_link_stitch_li[i][E] = '0;
        assign lce_cmd_link_stitch_li[i][E] = '0;
        assign lce_data_cmd_link_stitch_li[i][E] = '0;
      end

    bp_tile
     #(.cfg_p(cfg_p)
       ,.trace_p(trace_p)
       ,.calc_debug_p(calc_debug_p)
       )
     tile
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.proc_cfg_i(proc_cfg)

       ,.my_x_i(i)
       ,.my_y_i(1'b1)

       // Router inputs
       ,.lce_req_link_i(lce_req_link_stitch_li[i])
       ,.lce_resp_link_i(lce_resp_link_stitch_li[i])
       ,.lce_data_resp_link_i(lce_data_resp_link_stitch_li[i])
       ,.lce_cmd_link_i(lce_cmd_link_stitch_li[i])
       ,.lce_data_cmd_link_i(lce_data_cmd_link_stitch_li[i])

       // Router outputs
       ,.lce_req_link_o(lce_req_link_stitch_lo[i+1])
       ,.lce_resp_link_o(lce_resp_link_stitch_lo[i+1])
       ,.lce_data_resp_link_o(lce_data_resp_link_stitch_lo[i+1])
       ,.lce_cmd_link_o(lce_cmd_link_stitch_lo[i+1])
       ,.lce_data_cmd_link_o(lce_data_cmd_link_stitch_lo[i+1])

       ,.mem_resp_i(mem_resp_i)
       ,.mem_resp_v_i(mem_resp_v_i)
       ,.mem_resp_ready_o(mem_resp_ready_o)

       ,.mem_data_resp_i(mem_data_resp_i)
       ,.mem_data_resp_v_i(mem_data_resp_v_i)
       ,.mem_data_resp_ready_o(mem_data_resp_ready_o)

       ,.mem_cmd_o(mem_cmd_o)
       ,.mem_cmd_v_o(mem_cmd_v_o)
       ,.mem_cmd_yumi_i(mem_cmd_yumi_i)

       ,.mem_data_cmd_o(mem_data_cmd_o)
       ,.mem_data_cmd_v_o(mem_data_cmd_v_o)
       ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_i)

       ,.timer_int_i(timer_int_i)
       ,.software_int_i(software_int_i)
       ,.external_int_i(external_int_i)

       ,.cce_inst_boot_rom_addr_o(cce_inst_boot_rom_addr_o)
       ,.cce_inst_boot_rom_data_i(cce_inst_boot_rom_data_i)

       ,.cmt_rd_w_v_o(cmt_rd_w_v_o[i])
       ,.cmt_rd_addr_o(cmt_rd_addr_o[i])
       ,.cmt_mem_w_v_o(cmt_mem_w_v_o[i])
       ,.cmt_mem_addr_o(cmt_mem_addr_o[i])
       ,.cmt_mem_op_o(cmt_mem_op_o[i])
       ,.cmt_data_o(cmt_data_o[i])
       );
  end // rof1

endmodule : bp_top_tiled

