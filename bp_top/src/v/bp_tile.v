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

   , localparam proc_cfg_width_lp = `bp_proc_cfg_width(num_core_p, num_lce_p)

   , localparam dirs_lp = 5 // S (Mem side) EW (LCE sides), P (Proc side)

   // Used to enable trace replay outputs for testbench
   , parameter trace_p      = 0
   , parameter calc_debug_p = 1
   , parameter debug_p      = 0 // Debug for the network (TODO: rename)

   , parameter x_cord_width_p = `BSG_SAFE_CLOG2(num_lce_p)
   , parameter y_cord_width_p = 1

   , localparam lce_cce_req_network_width_lp = 
       lce_cce_req_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1
   , localparam lce_cce_resp_network_width_lp = 
       lce_cce_resp_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1
   , localparam cce_lce_cmd_network_width_lp = 
       cce_lce_cmd_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1
   , localparam lce_cce_data_resp_network_width_lp = 
       lce_cce_data_resp_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1
   , localparam lce_data_cmd_network_width_lp = 
       lce_data_cmd_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1
   )
  (input                                                   clk_i
   , input                                                 reset_i

   , input [proc_cfg_width_lp-1:0]                         proc_cfg_i

   , input [x_cord_width_p-1:0]                            my_x_i
   , input [y_cord_width_p-1:0]                            my_y_i

   // This will go away with the manycore bridge
   , output [`BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)-1:0] cce_inst_boot_rom_addr_o
   , input [`bp_cce_inst_width-1:0]                        cce_inst_boot_rom_data_i

   // Router - Inputs 
   // Connected on east and west
   , input [E:W][2+lce_cce_req_network_width_lp-1:0]       lce_req_link_i
   , input [E:W][2+lce_cce_resp_network_width_lp-1:0]      lce_resp_link_i
   , input [E:W][2+cce_lce_cmd_network_width_lp-1:0]       lce_cmd_link_i
   , input [E:W][2+lce_cce_data_resp_network_width_lp-1:0] lce_data_resp_link_i
   , input [E:W][2+lce_data_cmd_network_width_lp-1:0]      lce_data_cmd_link_i

   // Router - Outputs
   // Connected on east and west
   , output [E:W][2+lce_cce_req_network_width_lp-1:0]       lce_req_link_o
   , output [E:W][2+lce_cce_resp_network_width_lp-1:0]      lce_resp_link_o
   , output [E:W][2+cce_lce_cmd_network_width_lp-1:0]       lce_cmd_link_o
   , output [E:W][2+lce_cce_data_resp_network_width_lp-1:0] lce_data_resp_link_o
   , output [E:W][2+lce_data_cmd_network_width_lp-1:0]      lce_data_cmd_link_o

   // Memory side connection
   // Connected on south
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
bp_lce_cce_req_s       [1:0] lce_req_lo;
logic                  [1:0] lce_req_v_lo, lce_req_ready_li;
bp_lce_cce_resp_s      [1:0] lce_resp_lo;
logic                  [1:0] lce_resp_v_lo, lce_resp_ready_li;
bp_lce_cce_data_resp_s [1:0] lce_data_resp_lo;
logic                  [1:0] lce_data_resp_v_lo, lce_data_resp_ready_li;
bp_cce_lce_cmd_s       [1:0] lce_cmd_li;
logic                  [1:0] lce_cmd_v_li, lce_cmd_ready_lo;
bp_lce_data_cmd_s      [1:0] lce_data_cmd_li;
logic                  [1:0] lce_data_cmd_v_li, lce_data_cmd_ready_lo;
bp_lce_data_cmd_s      [1:0] lce_lce_data_cmd_lo;
logic                  [1:0] lce_lce_data_cmd_v_lo, lce_lce_data_cmd_ready_li;

// CCE connections
bp_lce_cce_req_s             lce_req_li;
logic                        lce_req_v_li, lce_req_ready_lo;
bp_lce_cce_resp_s            lce_resp_li;
logic                        lce_resp_v_li, lce_resp_ready_lo;
bp_lce_cce_data_resp_s       lce_data_resp_li;
logic                        lce_data_resp_v_li, lce_data_resp_ready_lo;
bp_cce_lce_cmd_s             lce_cmd_lo;
logic                        lce_cmd_v_lo, lce_cmd_ready_li;
bp_lce_data_cmd_s            cce_lce_data_cmd_lo;
logic                        cce_lce_data_cmd_v_lo, cce_lce_data_cmd_ready_li;

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

   ,.lce_data_cmd_o(lce_lce_data_cmd_lo)
   ,.lce_data_cmd_v_o(lce_lce_data_cmd_v_lo)
   ,.lce_data_cmd_ready_i(lce_lce_data_cmd_ready_li)

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

// Declare the routing links
`declare_bsg_ready_and_link_sif_s(lce_cce_req_network_width_lp, bp_lce_req_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(lce_cce_resp_network_width_lp, bp_lce_resp_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(cce_lce_cmd_network_width_lp, bp_lce_cmd_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(lce_data_cmd_network_width_lp, bp_lce_data_cmd_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(lce_cce_data_resp_network_width_lp, bp_lce_data_resp_ready_and_link_sif_s);

bp_lce_req_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_req_link_i_stitch, lce_req_link_o_stitch;
bp_lce_resp_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_resp_link_i_stitch, lce_resp_link_o_stitch;
bp_lce_cmd_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_cmd_link_i_stitch, lce_cmd_link_o_stitch;
bp_lce_data_cmd_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_data_cmd_link_i_stitch, lce_data_cmd_link_o_stitch;
bp_lce_data_resp_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_data_resp_link_i_stitch, lce_data_resp_link_o_stitch;

// Extract destination ids from packets
wire [x_cord_width_p-1:0] lce_req_dst_x_cord_0_lo           = lce_req_lo[0].dst_id;
wire [x_cord_width_p-1:0] lce_req_dst_x_cord_1_lo           = lce_req_lo[1].dst_id;
wire [x_cord_width_p-1:0] lce_resp_dst_x_cord_0_lo          = lce_resp_lo[0].dst_id;
wire [x_cord_width_p-1:0] lce_resp_dst_x_cord_1_lo          = lce_resp_lo[1].dst_id;
wire [x_cord_width_p-1:0] lce_data_resp_dst_x_cord_0_lo     = lce_data_resp_lo[0].dst_id;
wire [x_cord_width_p-1:0] lce_data_resp_dst_x_cord_1_lo     = lce_data_resp_lo[1].dst_id;
wire [x_cord_width_p-1:0] lce_cmd_dst_x_cord_lo             = lce_cmd_lo.dst_id;
wire [x_cord_width_p-1:0] lce_lce_data_cmd_dst_x_cord_0_lo  = lce_lce_data_cmd_lo[0].dst_id;
wire [x_cord_width_p-1:0] lce_lce_data_cmd_dst_x_cord_1_lo  = lce_lce_data_cmd_lo[1].dst_id;
wire [x_cord_width_p-1:0] cce_lce_data_cmd_dst_x_cord_lo    = cce_lce_data_cmd_lo.dst_id;

for (genvar i = 0; i < dirs_lp; i++)
  begin : rof1
    if (i == E) // Transfer side
      begin : fi1_E
        assign lce_req_link_i_stitch[1][E]       = lce_req_link_i[E];
        assign lce_resp_link_i_stitch[1][E]      = lce_resp_link_i[E];
        assign lce_data_resp_link_i_stitch[1][E] = lce_data_resp_link_i[E];
        assign lce_cmd_link_i_stitch[1][E]       = lce_cmd_link_i[E];
        assign lce_data_cmd_link_i_stitch[1][E]  = lce_data_cmd_link_i[E];

        assign lce_req_link_i_stitch[0][E]       = lce_req_link_o_stitch[1][W];
        assign lce_resp_link_i_stitch[0][E]      = lce_resp_link_o_stitch[1][W];
        assign lce_data_resp_link_i_stitch[0][E] = lce_data_resp_link_o_stitch[1][W];
        assign lce_cmd_link_i_stitch[0][E]       = lce_cmd_link_o_stitch[1][W];
        assign lce_data_cmd_link_i_stitch[0][E]  = lce_data_cmd_link_o_stitch[1][W];

        assign lce_req_link_o[W]       = lce_req_link_o_stitch[0][W];
        assign lce_resp_link_o[W]      = lce_resp_link_o_stitch[0][W];
        assign lce_data_resp_link_o[W] = lce_data_resp_link_o_stitch[0][W];
        assign lce_cmd_link_o[W]       = lce_cmd_link_o_stitch[0][W];
        assign lce_data_cmd_link_o[W]  = lce_data_cmd_link_o_stitch[0][W];
      end
    else if (i == W) // Transfer side
      begin : fi1_W
        assign lce_req_link_i_stitch[0][W]       = lce_req_link_i[W];
        assign lce_resp_link_i_stitch[0][W]      = lce_resp_link_i[W];
        assign lce_data_resp_link_i_stitch[0][W] = lce_data_resp_link_i[W];
        assign lce_cmd_link_i_stitch[0][W]       = lce_cmd_link_i[W];
        assign lce_data_cmd_link_i_stitch[0][W]  = lce_data_cmd_link_i[W];

        assign lce_req_link_i_stitch[1][W]       = lce_req_link_o_stitch[0][E];
        assign lce_resp_link_i_stitch[1][W]      = lce_resp_link_o_stitch[0][E];
        assign lce_data_resp_link_i_stitch[1][W] = lce_data_resp_link_o_stitch[0][E];
        assign lce_cmd_link_i_stitch[1][W]       = lce_cmd_link_o_stitch[0][E];
        assign lce_data_cmd_link_i_stitch[1][W]  = lce_data_cmd_link_o_stitch[0][E];

        assign lce_req_link_o[E]       = lce_req_link_o_stitch[1][E];
        assign lce_resp_link_o[E]      = lce_resp_link_o_stitch[1][E];
        assign lce_data_resp_link_o[E] = lce_data_resp_link_o_stitch[1][E];
        assign lce_cmd_link_o[E]       = lce_cmd_link_o_stitch[1][E];
        assign lce_data_cmd_link_o[E]  = lce_data_cmd_link_o_stitch[1][E];
      end
    else if (i == P) // Destination side
      begin : fi1_P
        assign lce_req_li   = lce_req_link_o_stitch[0][P].data[1+x_cord_width_p+:lce_cce_req_width_lp];
        assign lce_req_v_li = lce_req_link_o_stitch[0][P].v;
        assign lce_req_link_i_stitch[0][P] = '{ready_and_rev: lce_req_ready_lo, default : '0};
        assign lce_req_link_i_stitch[1][P] = '{ready_and_rev: lce_req_ready_lo, default : '0};

        assign lce_resp_li   = lce_resp_link_o_stitch[0][P].data[1+x_cord_width_p+:lce_cce_resp_width_lp];
        assign lce_resp_v_li = lce_resp_link_o_stitch[0][P].v;
        assign lce_resp_link_i_stitch[0][P] = '{ready_and_rev: lce_resp_ready_lo, default : '0};
        assign lce_resp_link_i_stitch[1][P] = '{ready_and_rev: lce_resp_ready_lo, default : '0};

        assign lce_data_resp_li   = lce_data_resp_link_o_stitch[0][P].data[1+x_cord_width_p+:lce_cce_data_resp_width_lp];
        assign lce_data_resp_v_li = lce_data_resp_link_o_stitch[0][P].v;
        assign lce_data_resp_link_i_stitch[0][P] = '{ready_and_rev: lce_data_resp_ready_lo, default : '0};
        assign lce_data_resp_link_i_stitch[1][P] = '{ready_and_rev: lce_data_resp_ready_lo, default : '0};

        assign lce_cmd_li[0]   = lce_cmd_link_o_stitch[0][P].data[1+x_cord_width_p+:cce_lce_cmd_width_lp]; 
        assign lce_cmd_v_li[0] = lce_cmd_link_o_stitch[0][P].v;
        assign lce_cmd_link_i_stitch[0][P]  = '{ready_and_rev: lce_cmd_ready_lo[0], default : '0};

        assign lce_data_cmd_li[0]   = lce_data_cmd_link_o_stitch[0][P].data[1+x_cord_width_p+:lce_data_cmd_width_lp];
        assign lce_data_cmd_v_li[0] = lce_data_cmd_link_o_stitch[0][P].v;
        assign lce_data_cmd_link_i_stitch[0][P] = '{ready_and_rev: lce_data_cmd_ready_lo[0], default : '0};

        assign lce_cmd_li[1]   = lce_cmd_link_o_stitch[1][P].data[1+x_cord_width_p+:cce_lce_cmd_width_lp]; 
        assign lce_cmd_v_li[1] = lce_cmd_link_o_stitch[1][P].v;
        assign lce_cmd_link_i_stitch[1][P]  = '{ready_and_rev: lce_cmd_ready_lo[1], default : '0};

        assign lce_data_cmd_li[1]   = lce_data_cmd_link_o_stitch[1][P].data[1+x_cord_width_p+:lce_data_cmd_width_lp];
        assign lce_data_cmd_v_li[1] = lce_data_cmd_link_o_stitch[1][P].v;
        assign lce_data_cmd_link_i_stitch[1][P] = '{ready_and_rev: lce_data_cmd_ready_lo[1], default : '0};
      end
    else if (i == S) // Source side
      begin : fi1_S
        assign lce_req_link_i_stitch[0][S].data          = {lce_req_lo[0], 1'b1, lce_req_dst_x_cord_0_lo}; 
        assign lce_req_link_i_stitch[0][S].v             = lce_req_v_lo[0];
        assign lce_req_link_i_stitch[0][S].ready_and_rev = '0;
        assign lce_req_ready_li[0] = lce_req_link_o_stitch[0][S].ready_and_rev;

        assign lce_resp_link_i_stitch[0][S].data          = {lce_resp_lo[0], 1'b1, lce_resp_dst_x_cord_0_lo};
        assign lce_resp_link_i_stitch[0][S].v             = lce_resp_v_lo[0];
        assign lce_resp_link_i_stitch[0][S].ready_and_rev = '0;
        assign lce_resp_ready_li[0] = lce_resp_link_o_stitch[0][S].ready_and_rev;

        assign lce_data_resp_link_i_stitch[0][S] = '0;

        assign lce_cmd_link_i_stitch[0][S].data          = {lce_cmd_lo, 1'b1, lce_cmd_dst_x_cord_lo};
        assign lce_cmd_link_i_stitch[0][S].v             = lce_cmd_v_lo;
        assign lce_cmd_link_i_stitch[0][S].ready_and_rev = '0;
        assign lce_cmd_ready_li = lce_cmd_link_o_stitch[0][S].ready_and_rev;

        assign lce_data_cmd_link_i_stitch[0][S].data          = {cce_lce_data_cmd_lo, 1'b1, cce_lce_data_cmd_dst_x_cord_lo};
        assign lce_data_cmd_link_i_stitch[0][S].v             = cce_lce_data_cmd_v_lo;
        assign lce_data_cmd_link_i_stitch[0][S].ready_and_rev = '0;
        assign cce_lce_data_cmd_ready_li = lce_data_cmd_link_o_stitch[0][S].ready_and_rev;

        assign lce_req_link_i_stitch[1][S].data          = {lce_req_lo[0], 1'b1, lce_req_dst_x_cord_1_lo}; 
        assign lce_req_link_i_stitch[1][S].v             = lce_req_v_lo[1];
        assign lce_req_link_i_stitch[1][S].ready_and_rev = '0;
        assign lce_req_ready_li[1] = lce_req_link_o_stitch[1][S].ready_and_rev;

        assign lce_resp_link_i_stitch[1][S].data          = {lce_resp_lo[0], 1'b1, lce_resp_dst_x_cord_1_lo}; 
        assign lce_resp_link_i_stitch[1][S].v             = lce_resp_v_lo[1];
        assign lce_resp_link_i_stitch[1][S].ready_and_rev = '0;
        assign lce_resp_ready_li[1] = lce_resp_link_o_stitch[1][S].ready_and_rev;

        assign lce_data_resp_link_i_stitch[1][S] = '0;

        // CCE is attached to icache exclusively
        assign lce_cmd_link_i_stitch[1][S] = '0;
        assign lce_data_cmd_link_i_stitch[1][S] = '0;
      end
    else
      begin : fi_N
        assign lce_req_link_i_stitch[0][N]  = '0;
        assign lce_resp_link_i_stitch[0][N] = '0;

        assign lce_data_resp_link_i_stitch[0][N].data          = {lce_data_resp_lo[0], 1'b1, lce_data_resp_dst_x_cord_0_lo};
        assign lce_data_resp_link_i_stitch[0][N].v             = lce_data_resp_v_lo[0];
        assign lce_data_resp_link_i_stitch[0][N].ready_and_rev = '0;
        assign lce_data_resp_ready_li[0] = lce_data_resp_link_o_stitch[0][N].ready_and_rev;

        assign lce_cmd_link_i_stitch[0][N]  = '0;

        assign lce_data_cmd_link_i_stitch[0][N].data          = {lce_lce_data_cmd_lo[0], 1'b1, lce_lce_data_cmd_dst_x_cord_0_lo};
        assign lce_data_cmd_link_i_stitch[0][N].v             = lce_lce_data_cmd_v_lo[0];
        assign lce_data_cmd_link_i_stitch[0][N].ready_and_rev = '0;
        assign lce_lce_data_cmd_ready_li[0] = lce_data_cmd_link_o_stitch[0][N].ready_and_rev;

        assign lce_req_link_i_stitch[1][N]  = '0;
        assign lce_resp_link_i_stitch[1][N] = '0;

        assign lce_data_resp_link_i_stitch[1][N].data          = {lce_data_resp_lo[1], 1'b1, lce_data_resp_dst_x_cord_1_lo};
        assign lce_data_resp_link_i_stitch[1][N].v             = lce_data_resp_v_lo[1];
        assign lce_data_resp_link_i_stitch[1][N].ready_and_rev = '0;
        assign lce_data_resp_ready_li[1] = lce_data_resp_link_o_stitch[1][N].ready_and_rev;

        assign lce_cmd_link_i_stitch[1][N]  = '0;

        assign lce_data_cmd_link_i_stitch[1][N].data          = {lce_lce_data_cmd_lo[1], 1'b1, lce_lce_data_cmd_dst_x_cord_1_lo};
        assign lce_data_cmd_link_i_stitch[1][N].v             = lce_lce_data_cmd_v_lo[1];
        assign lce_data_cmd_link_i_stitch[1][N].ready_and_rev = '0;
        assign lce_lce_data_cmd_ready_li[1] = lce_data_cmd_link_o_stitch[0][N].ready_and_rev;
      end
  end // rof1

for (genvar i = 0; i < 2; i++)
  begin : rof3
    bsg_mesh_router_buffered
     #(.width_p(lce_cce_req_network_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ,.XY_order_p(0)
       )
     req_router
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.link_i(lce_req_link_i_stitch[i])
       ,.link_o(lce_req_link_o_stitch[i])
       ,.my_x_i(my_x_i+i)
       ,.my_y_i(my_y_i)
       );
    
    bsg_mesh_router_buffered
     #(.width_p(lce_cce_resp_network_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ,.XY_order_p(0)
       )
     resp_router
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.link_i(lce_resp_link_i_stitch[i])
       ,.link_o(lce_resp_link_o_stitch[i])
       ,.my_x_i(my_x_i+i)
       ,.my_y_i(my_y_i)
       );
    
    bsg_mesh_router_buffered
     #(.width_p(lce_cce_data_resp_network_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ,.XY_order_p(0)
       )
     data_resp_router
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.link_i(lce_data_resp_link_i_stitch[i])
       ,.link_o(lce_data_resp_link_o_stitch[i])
       ,.my_x_i(my_x_i+i)
       ,.my_y_i(my_y_i)
       );

    bsg_mesh_router_buffered
     #(.width_p(cce_lce_cmd_network_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ,.XY_order_p(0)
       )
     cmd_router
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.link_i(lce_cmd_link_i_stitch[i])
       ,.link_o(lce_cmd_link_o_stitch[i])
       ,.my_x_i(my_x_i+i)
       ,.my_y_i(my_y_i)
       );

    bsg_mesh_router_buffered
     #(.width_p(lce_data_cmd_network_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ,.XY_order_p(0)
       )
     data_cmd_router
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.link_i(lce_data_cmd_link_i_stitch[i])
       ,.link_o(lce_data_cmd_link_o_stitch[i])
       ,.my_x_i(my_x_i+i)
       ,.my_y_i(my_y_i)
       );
    
  end // rof3    
    
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

   // To CCE
   ,.lce_req_i(lce_req_li)
   ,.lce_req_v_i(lce_req_v_li)
   ,.lce_req_ready_o(lce_req_ready_lo)

   ,.lce_resp_i(lce_resp_li)
   ,.lce_resp_v_i(lce_resp_v_li)
   ,.lce_resp_ready_o(lce_resp_ready_lo)

   ,.lce_data_resp_i(lce_data_resp_li)
   ,.lce_data_resp_v_i(lce_data_resp_v_li)
   ,.lce_data_resp_ready_o(lce_data_resp_ready_lo)

   // From CCE
   ,.lce_cmd_o(lce_cmd_lo)
   ,.lce_cmd_v_o(lce_cmd_v_lo)
   ,.lce_cmd_ready_i(lce_cmd_ready_li)

   ,.lce_data_cmd_o(cce_lce_data_cmd_lo)
   ,.lce_data_cmd_v_o(cce_lce_data_cmd_v_lo)
   ,.lce_data_cmd_ready_i(cce_lce_data_cmd_ready_li)

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

   ,.cce_id_i(proc_cfg_cast_i.icache_id / 2) // TODO: Make part of proc cfg

   ,.boot_rom_addr_o(cce_inst_boot_rom_addr_o)
   ,.boot_rom_data_i(cce_inst_boot_rom_data_i)
   );
   

endmodule : bp_tile

