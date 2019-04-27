/**
 *
 * bp_top.v
 *
 */

module bp_top
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   // Used to enable trace replay outputs for testbench
   , parameter trace_p      = 0
   , parameter calc_debug_p = 1
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

   , input [num_core_p-1:0]                                   external_int_i

   // Commit tracer for trace replay
   , output [num_core_p-1:0]                                  cmt_rd_w_v_o
   , output [num_core_p-1:0][rv64_reg_addr_width_gp-1:0]      cmt_rd_addr_o
   , output [num_core_p-1:0]                                  cmt_mem_w_v_o
   , output [num_core_p-1:0][dword_width_p-1:0]               cmt_mem_addr_o
   , output [num_core_p-1:0][`bp_be_fu_op_width-1:0]          cmt_mem_op_o
   , output [num_core_p-1:0][dword_width_p-1:0]               cmt_data_o
  );

`declare_bp_common_proc_cfg_s(num_core_p, num_lce_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
`declare_bp_lce_cce_if(num_cce_p
                       ,num_lce_p
                       ,paddr_width_p
                       ,lce_assoc_p
                       ,dword_width_p
                       ,cce_block_width_p
                       )

// Top-level interface connections
bp_lce_cce_req_s [num_core_p-1:0][1:0] lce_req_lo;
logic [num_core_p-1:0][1:0] lce_req_v_lo, lce_req_ready_li;

bp_lce_cce_resp_s [num_core_p-1:0][1:0] lce_resp_lo;
logic [num_core_p-1:0][1:0] lce_resp_v_lo, lce_resp_ready_li;

bp_lce_cce_data_resp_s [num_core_p-1:0][1:0] lce_data_resp_lo;
logic [num_core_p-1:0][1:0] lce_data_resp_v_lo, lce_data_resp_ready_li;

bp_cce_lce_cmd_s [num_core_p-1:0][1:0] lce_cmd_li;
logic [num_core_p-1:0][1:0] lce_cmd_v_li, lce_cmd_ready_lo;

bp_lce_data_cmd_s [num_core_p-1:0][1:0] lce_data_cmd_li;
logic [num_core_p-1:0][1:0] lce_data_cmd_v_li, lce_data_cmd_ready_lo;

bp_lce_data_cmd_s [num_core_p-1:0][1:0] lce_data_cmd_lo;
logic [num_core_p-1:0][1:0] lce_data_cmd_v_lo, lce_data_cmd_ready_li;

logic [num_core_p-1:0] timer_int_li, software_int_li;

// Module instantiations
generate 
for(genvar core_id = 0; core_id < num_core_p; core_id++) 
  begin : rof1
    localparam mhartid   = core_id;
    localparam icache_id = (core_id * 2 + 0);
    localparam dcache_id = (core_id * 2 + 1);

    localparam mhartid_width_lp = `BSG_SAFE_CLOG2(num_core_p);
    localparam lce_id_width_lp  = `BSG_SAFE_CLOG2(num_lce_p);

    bp_proc_cfg_s proc_cfg;
    assign proc_cfg.mhartid   = mhartid[0+:mhartid_width_lp];
    assign proc_cfg.icache_id = icache_id[0+:lce_id_width_lp];
    assign proc_cfg.dcache_id = dcache_id[0+:lce_id_width_lp];

    bp_core   
     #(.cfg_p(cfg_p)
       ,.trace_p(trace_p)
       ,.calc_debug_p(calc_debug_p)
       )
     core 
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.proc_cfg_i(proc_cfg)

       ,.lce_req_o(lce_req_lo[core_id])
       ,.lce_req_v_o(lce_req_v_lo[core_id])
       ,.lce_req_ready_i(lce_req_ready_li[core_id])

       ,.lce_resp_o(lce_resp_lo[core_id])
       ,.lce_resp_v_o(lce_resp_v_lo[core_id])
       ,.lce_resp_ready_i(lce_resp_ready_li[core_id])

       ,.lce_data_resp_o(lce_data_resp_lo[core_id])
       ,.lce_data_resp_v_o(lce_data_resp_v_lo[core_id])
       ,.lce_data_resp_ready_i(lce_data_resp_ready_li[core_id])

       ,.lce_cmd_i(lce_cmd_li[core_id])
       ,.lce_cmd_v_i(lce_cmd_v_li[core_id])
       ,.lce_cmd_ready_o(lce_cmd_ready_lo[core_id])

       ,.lce_data_cmd_i(lce_data_cmd_li[core_id])
       ,.lce_data_cmd_v_i(lce_data_cmd_v_li[core_id])
       ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo[core_id])

       ,.lce_data_cmd_o(lce_data_cmd_lo[core_id])
       ,.lce_data_cmd_v_o(lce_data_cmd_v_lo[core_id])
       ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li[core_id])

       ,.timer_int_i(timer_int_li[core_id])
       ,.software_int_i(software_int_li[core_id])
       ,.external_int_i(external_int_i[core_id])

       ,.cmt_rd_w_v_o(cmt_rd_w_v_o[core_id])
       ,.cmt_rd_addr_o(cmt_rd_addr_o[core_id])
       ,.cmt_mem_w_v_o(cmt_mem_w_v_o[core_id])
       ,.cmt_mem_addr_o(cmt_mem_addr_o[core_id])
       ,.cmt_mem_op_o(cmt_mem_op_o[core_id])
       ,.cmt_data_o(cmt_data_o[core_id])
       );
  end
endgenerate 

// Config link parameters
// TODO: move these into proc cfg?
localparam cfg_link_addr_width_p       = 16;
localparam cfg_link_data_width_p       = 32;

bp_mem_cce_resp_s      [num_cce_p-1:0] me_mem_resp_li;
logic                  [num_cce_p-1:0] me_mem_resp_v_li, me_mem_resp_ready_lo;

bp_mem_cce_data_resp_s [num_cce_p-1:0] me_mem_data_resp_li;
logic                  [num_cce_p-1:0] me_mem_data_resp_v_li, me_mem_data_resp_ready_lo;

bp_cce_mem_cmd_s       [num_cce_p-1:0] me_mem_cmd_lo;
logic                  [num_cce_p-1:0] me_mem_cmd_v_lo, me_mem_cmd_yumi_li;

bp_cce_mem_data_cmd_s  [num_cce_p-1:0] me_mem_data_cmd_lo;
logic                  [num_cce_p-1:0] me_mem_data_cmd_v_lo, me_mem_data_cmd_yumi_li;

bp_me_top 
 #(.cfg_p(cfg_p)
   ,.cfg_link_addr_width_p(cfg_link_addr_width_p)
   ,.cfg_link_data_width_p(cfg_link_data_width_p)
 )
 me
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.freeze_i('0)

   ,.config_addr_i('0)
   ,.config_data_i('0)
   ,.config_v_i('0)
   ,.config_w_i('0)
   ,.config_ready_o()

   ,.config_data_o()
   ,.config_v_o()
   ,.config_ready_i('0)

   ,.lce_req_i(lce_req_lo)
   ,.lce_req_v_i(lce_req_v_lo)
   ,.lce_req_ready_o(lce_req_ready_li)

   ,.lce_resp_i(lce_resp_lo)
   ,.lce_resp_v_i(lce_resp_v_lo)
   ,.lce_resp_ready_o(lce_resp_ready_li)        

   ,.lce_data_resp_i(lce_data_resp_lo)
   ,.lce_data_resp_v_i(lce_data_resp_v_lo)
   ,.lce_data_resp_ready_o(lce_data_resp_ready_li)

   ,.lce_cmd_o(lce_cmd_li)
   ,.lce_cmd_v_o(lce_cmd_v_li)
   ,.lce_cmd_ready_i(lce_cmd_ready_lo)

   ,.lce_data_cmd_o(lce_data_cmd_li)
   ,.lce_data_cmd_v_o(lce_data_cmd_v_li)
   ,.lce_data_cmd_ready_i(lce_data_cmd_ready_lo)

   ,.lce_data_cmd_i(lce_data_cmd_lo)
   ,.lce_data_cmd_v_i(lce_data_cmd_v_lo)
   ,.lce_data_cmd_ready_o(lce_data_cmd_ready_li)

   ,.cce_inst_boot_rom_addr_o(cce_inst_boot_rom_addr_o)
   ,.cce_inst_boot_rom_data_i(cce_inst_boot_rom_data_i)
  
   ,.mem_resp_i(me_mem_resp_li)
   ,.mem_resp_v_i(me_mem_resp_v_li)
   ,.mem_resp_ready_o(me_mem_resp_ready_lo)

   ,.mem_data_resp_i(me_mem_data_resp_li)
   ,.mem_data_resp_v_i(me_mem_data_resp_v_li)
   ,.mem_data_resp_ready_o(me_mem_data_resp_ready_lo)

   ,.mem_cmd_o(me_mem_cmd_lo)
   ,.mem_cmd_v_o(me_mem_cmd_v_lo)
   ,.mem_cmd_yumi_i(me_mem_cmd_yumi_li)

   ,.mem_data_cmd_o(me_mem_data_cmd_lo)
   ,.mem_data_cmd_v_o(me_mem_data_cmd_v_lo)
   ,.mem_data_cmd_yumi_i(me_mem_data_cmd_yumi_li)
   );

bp_cce_mem_cmd_s        mtime_cmd_li;
logic                   mtime_cmd_v_li, mtime_cmd_yumi_lo;
bp_cce_mem_data_cmd_s   mtime_data_cmd_li;
logic                   mtime_data_cmd_v_li, mtime_data_cmd_yumi_lo;
bp_mem_cce_resp_s       mtime_resp_lo;
logic                   mtime_resp_v_lo, mtime_resp_ready_li;
bp_mem_cce_data_resp_s  mtime_data_resp_lo;
logic                   mtime_data_resp_v_lo, mtime_data_resp_ready_li;

bp_cce_mem_cmd_s [num_cce_p-1:0]       mtimecmp_cmd_li;
logic [num_cce_p-1:0]                  mtimecmp_cmd_v_li, mtimecmp_cmd_yumi_lo;
bp_cce_mem_data_cmd_s [num_cce_p-1:0]  mtimecmp_data_cmd_li;
logic [num_cce_p-1:0]                  mtimecmp_data_cmd_v_li, mtimecmp_data_cmd_yumi_lo;
bp_mem_cce_resp_s [num_cce_p-1:0]      mtimecmp_resp_lo;
logic [num_cce_p-1:0]                  mtimecmp_resp_v_lo, mtimecmp_resp_ready_li;
bp_mem_cce_data_resp_s [num_cce_p-1:0] mtimecmp_data_resp_lo;
logic [num_cce_p-1:0]                  mtimecmp_data_resp_v_lo, mtimecmp_data_resp_ready_li;

bp_cce_mem_cmd_s [num_cce_p-1:0]       msoftint_cmd_li;
logic [num_cce_p-1:0]                  msoftint_cmd_v_li, msoftint_cmd_yumi_lo;
bp_cce_mem_data_cmd_s [num_cce_p-1:0]  msoftint_data_cmd_li;
logic [num_cce_p-1:0]                  msoftint_data_cmd_v_li, msoftint_data_cmd_yumi_lo;
bp_mem_cce_resp_s [num_cce_p-1:0]      msoftint_resp_lo;
logic [num_cce_p-1:0]                  msoftint_resp_v_lo, msoftint_resp_ready_li;
bp_mem_cce_data_resp_s [num_cce_p-1:0] msoftint_data_resp_lo;
logic [num_cce_p-1:0]                  msoftint_data_resp_v_lo, msoftint_data_resp_ready_li;

// 1 softint, 1 timecmp per cce and then 1 global mtime
localparam num_io_lp = (2*num_cce_p + 1);
for (genvar i = 0; i < num_cce_p; i++)
  begin : rof2
    bp_cce_io_router
     #(.num_cce_p(num_cce_p)
       ,.paddr_width_p(paddr_width_p)
       ,.num_lce_p(num_lce_p)
       ,.block_size_in_bits_p(cce_block_width_p)
       ,.lce_assoc_p(lce_assoc_p)
       ,.num_io_p(num_io_lp)
       )
     mmio
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       // ME side
       ,.mem_cmd_i(me_mem_cmd_lo[i])
       ,.mem_cmd_v_i(me_mem_cmd_v_lo[i])
       ,.mem_cmd_yumi_o(me_mem_cmd_yumi_li[i])

       ,.mem_data_cmd_i(me_mem_data_cmd_lo[i])
       ,.mem_data_cmd_v_i(me_mem_data_cmd_v_lo[i])
       ,.mem_data_cmd_yumi_o(me_mem_data_cmd_yumi_li[i])

       ,.mem_resp_o(me_mem_resp_li[i])
       ,.mem_resp_v_o(me_mem_resp_v_li[i])
       ,.mem_resp_ready_i(me_mem_resp_ready_lo[i])

       ,.mem_data_resp_o(me_mem_data_resp_li[i])
       ,.mem_data_resp_v_o(me_mem_data_resp_v_li[i])
       ,.mem_data_resp_ready_i(me_mem_data_resp_ready_lo[i])

       // Mem side
       ,.mem_cmd_o(mem_cmd_o[i])
       ,.mem_cmd_v_o(mem_cmd_v_o[i])
       ,.mem_cmd_yumi_i(mem_cmd_yumi_i[i])

       ,.mem_data_cmd_o(mem_data_cmd_o[i])
       ,.mem_data_cmd_v_o(mem_data_cmd_v_o[i])
       ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_i[i])

       ,.mem_resp_i(mem_resp_i[i])
       ,.mem_resp_v_i(mem_resp_v_i[i])
       ,.mem_resp_ready_o(mem_resp_ready_o[i])

       ,.mem_data_resp_i(mem_data_resp_i[i])
       ,.mem_data_resp_v_i(mem_data_resp_v_i[i])
       ,.mem_data_resp_ready_o(mem_data_resp_ready_o[i])

       // IO side
       ,.io_cmd_o({msoftint_cmd_li, mtimecmp_cmd_li, mtime_cmd_li})
       ,.io_cmd_v_o({msoftint_cmd_v_li, mtimecmp_cmd_v_li, mtime_cmd_v_li})
       ,.io_cmd_yumi_i({msoftint_cmd_yumi_lo, mtimecmp_cmd_yumi_lo, mtime_cmd_yumi_lo})

       ,.io_data_cmd_o({msoftint_data_cmd_li, mtimecmp_data_cmd_li, mtime_data_cmd_li})
       ,.io_data_cmd_v_o({msoftint_data_cmd_v_li, mtimecmp_data_cmd_v_li, mtime_data_cmd_v_li})
       ,.io_data_cmd_yumi_i({msoftint_data_cmd_yumi_lo, mtimecmp_data_cmd_yumi_lo, mtime_data_cmd_yumi_lo})

       ,.io_resp_i({msoftint_resp_lo, mtimecmp_resp_lo, mtime_resp_lo})
       ,.io_resp_v_i({msoftint_resp_v_lo, mtimecmp_resp_v_lo, mtime_resp_v_lo})
       ,.io_resp_ready_o({msoftint_resp_ready_li, mtimecmp_resp_ready_li, mtime_resp_ready_li})

       ,.io_data_resp_i({msoftint_data_resp_lo, mtimecmp_data_resp_lo, mtime_data_resp_lo})
       ,.io_data_resp_v_i({msoftint_data_resp_v_lo, mtimecmp_data_resp_v_lo, mtime_data_resp_v_lo})
       ,.io_data_resp_ready_o({msoftint_data_resp_ready_li, mtimecmp_data_resp_ready_li, mtime_data_resp_ready_li})
       );
  end

bp_io_enclave
 #(.num_cce_p(num_cce_p)
   ,.paddr_width_p(paddr_width_p)
   ,.num_lce_p(num_lce_p)
   ,.block_size_in_bits_p(cce_block_width_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.dword_width_p(dword_width_p)
   )
 io_enclave
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   // Real time clock input (currently tied to regular clock)
   ,.rtc_i(clk_i)

   // Timer read
   ,.mtime_cmd_i(mtime_cmd_li)
   ,.mtime_cmd_v_i(mtime_cmd_v_li)
   ,.mtime_cmd_yumi_o(mtime_cmd_yumi_lo)

   ,.mtime_data_cmd_i(mtime_data_cmd_li)
   ,.mtime_data_cmd_v_i(mtime_data_cmd_v_li)
   ,.mtime_data_cmd_yumi_o(mtime_data_cmd_yumi_lo)

   ,.mtime_resp_o(mtime_resp_lo)
   ,.mtime_resp_v_o(mtime_resp_v_lo)
   ,.mtime_resp_ready_i(mtime_resp_ready_li)

   ,.mtime_data_resp_o(mtime_data_resp_lo)
   ,.mtime_data_resp_v_o(mtime_data_resp_v_lo)
   ,.mtime_data_resp_ready_i(mtime_data_resp_ready_li)

   // Timer compare
   ,.mtimecmp_cmd_i(mtimecmp_cmd_li)
   ,.mtimecmp_cmd_v_i(mtimecmp_cmd_v_li)
   ,.mtimecmp_cmd_yumi_o(mtimecmp_cmd_yumi_lo)

   ,.mtimecmp_data_cmd_i(mtimecmp_data_cmd_li)
   ,.mtimecmp_data_cmd_v_i(mtimecmp_data_cmd_v_li)
   ,.mtimecmp_data_cmd_yumi_o(mtimecmp_data_cmd_yumi_lo)

   ,.mtimecmp_resp_o(mtimecmp_resp_lo)
   ,.mtimecmp_resp_v_o(mtimecmp_resp_v_lo)
   ,.mtimecmp_resp_ready_i(mtimecmp_resp_ready_li)

   ,.mtimecmp_data_resp_o(mtimecmp_data_resp_lo)
   ,.mtimecmp_data_resp_v_o(mtimecmp_data_resp_v_lo)
   ,.mtimecmp_data_resp_ready_i(mtimecmp_data_resp_ready_li)

   // Software interrupt
   ,.msoftint_cmd_i(msoftint_cmd_li)
   ,.msoftint_cmd_v_i(msoftint_cmd_v_li)
   ,.msoftint_cmd_yumi_o(msoftint_cmd_yumi_lo)

   ,.msoftint_data_cmd_i(msoftint_data_cmd_li)
   ,.msoftint_data_cmd_v_i(msoftint_data_cmd_v_li)
   ,.msoftint_data_cmd_yumi_o(msoftint_data_cmd_yumi_lo)

   ,.msoftint_resp_o(msoftint_resp_lo)
   ,.msoftint_resp_v_o(msoftint_resp_v_lo)
   ,.msoftint_resp_ready_i(msoftint_resp_ready_li)

   ,.msoftint_data_resp_o(msoftint_data_resp_lo)
   ,.msoftint_data_resp_v_o(msoftint_data_resp_v_lo)
   ,.msoftint_data_resp_ready_i(msoftint_data_resp_ready_li)

   // Interrupts
   ,.timer_int_o(timer_int_li)
   ,.software_int_o(software_int_li)
   );

endmodule : bp_top

