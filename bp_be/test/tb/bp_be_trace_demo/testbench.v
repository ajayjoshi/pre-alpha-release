/**
 *
 * testbench.v
 *
 */

module testbench
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_cce_pkg::*;
 #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(cfg_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p
                               ,paddr_width_p
                               ,asid_width_p
                               ,branch_metadata_fwd_width_p
                               )
   `declare_bp_me_if_widths(paddr_width_p, dword_width_p, num_lce_p, lce_assoc_p)

   , localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
   , parameter mem_els_p                   = "inv"
   , parameter boot_rom_width_p            = "inv"
   , parameter boot_rom_els_p              = "inv"
   , localparam lg_boot_rom_els_lp         = `BSG_SAFE_CLOG2(boot_rom_els_p)

   , parameter trace_p                  = 0
   , parameter trace_ring_width_p       = "inv"
   , localparam trace_rom_data_width_lp = trace_ring_width_p + 4
   , parameter trace_rom_addr_width_p   = "inv"

   , parameter calc_debug_p      = 0
   )
  (input clk_i
   , input reset_i
   );


`declare_bp_common_proc_cfg_s(num_core_p, num_lce_p)
`declare_bp_fe_be_if(vaddr_width_p
                     ,paddr_width_p
                     ,asid_width_p
                     ,branch_metadata_fwd_width_p
                     )
`declare_bp_lce_cce_if(num_cce_p
                       ,num_lce_p
                       ,paddr_width_p
                       ,lce_assoc_p
                       ,dword_width_p
                       ,cce_block_width_p
                       )
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   )

logic clk, reset, test_done;

bp_fe_queue_s fe_fe_queue, be_fe_queue;
logic fe_fe_queue_v, be_fe_queue_v, fe_fe_queue_rdy, be_fe_queue_rdy;

logic [lg_boot_rom_els_lp-1:0] irom_addr;
logic [boot_rom_width_p-1:0]   irom_data;


logic [num_cce_p-1:0][lg_boot_rom_els_lp-1:0] mrom_addr;
logic [num_cce_p-1:0][boot_rom_width_p-1:0]   mrom_data;

// CCE Inst Boot ROM
logic [num_cce_p-1:0][cce_instr_ram_addr_width_lp-1:0] cce_inst_boot_rom_addr;
logic [num_cce_p-1:0][`bp_cce_inst_width-1:0]         cce_inst_boot_rom_data;

logic fe_queue_clr, fe_queue_dequeue, fe_queue_rollback;

bp_fe_cmd_s fe_fe_cmd, be_fe_cmd;
logic fe_fe_cmd_v, be_fe_cmd_v, fe_fe_cmd_rdy, be_fe_cmd_rdy;

bp_lce_cce_req_s lce_req, lce_cce_req;
logic lce_cce_req_v, lce_cce_req_rdy;

bp_lce_cce_resp_s lce_cce_resp;
logic lce_cce_resp_v, lce_cce_resp_rdy;

bp_lce_cce_data_resp_s lce_cce_data_resp;
logic lce_cce_data_resp_v, lce_cce_data_resp_rdy;

bp_cce_lce_cmd_s cce_lce_cmd;
logic cce_lce_cmd_v, cce_lce_cmd_rdy;

bp_lce_data_cmd_s lce_data_cmd_li, lce_data_cmd_lo;
logic lce_data_cmd_v_li, lce_data_cmd_v_lo, lce_data_cmd_rdy_li, lce_data_cmd_rdy_lo;

logic                              cmt_rd_w_v;
logic [rv64_reg_addr_width_gp-1:0] cmt_rd_addr;
logic                              cmt_mem_w_v;
logic [dword_width_p-1:0]          cmt_mem_addr;
logic [`bp_be_fu_op_width-1:0]     cmt_mem_op;
logic [dword_width_p-1:0]          cmt_data;

logic timer_int, software_int, external_int;

bp_proc_cfg_s proc_cfg;

logic [trace_ring_width_p-1:0] tr_data_li;
logic tr_v_li, tr_ready_lo;

logic [trace_rom_addr_width_p-1:0]  tr_rom_addr_li;
logic [trace_rom_data_width_lp-1:0] tr_rom_data_lo;

assign proc_cfg.mhartid   = 1'b0;
assign proc_cfg.icache_id = 1'b1; // Unused
assign proc_cfg.dcache_id = 1'b0;

wrapper
 #(.cfg_p(cfg_p)
   ,.trace_p(trace_p)
   ,.calc_debug_p(calc_debug_p)
   )
 wrapper
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.fe_queue_i(be_fe_queue)
   ,.fe_queue_v_i(be_fe_queue_v)
   ,.fe_queue_ready_o(be_fe_queue_rdy)

   ,.fe_queue_clr_o(fe_queue_clr)
   ,.fe_queue_dequeue_o(fe_queue_dequeue)
   ,.fe_queue_rollback_o(fe_queue_rollback)

   ,.fe_cmd_o(be_fe_cmd)
   ,.fe_cmd_v_o(be_fe_cmd_v)
   
   ,.fe_cmd_ready_i(be_fe_cmd_rdy)

   ,.lce_req_o(lce_cce_req)
   ,.lce_req_v_o(lce_cce_req_v)
   ,.lce_req_ready_i(lce_cce_req_rdy)

   ,.lce_resp_o(lce_cce_resp)
   ,.lce_resp_v_o(lce_cce_resp_v)
   ,.lce_resp_ready_i(lce_cce_resp_rdy)

   ,.lce_data_resp_o(lce_cce_data_resp)
   ,.lce_data_resp_v_o(lce_cce_data_resp_v)
   ,.lce_data_resp_ready_i(lce_cce_data_resp_rdy)

   ,.lce_cmd_i(cce_lce_cmd)
   ,.lce_cmd_v_i(cce_lce_cmd_v)
   ,.lce_cmd_ready_o(cce_lce_cmd_rdy)

   ,.lce_data_cmd_i(lce_data_cmd_li)
   ,.lce_data_cmd_v_i(lce_data_cmd_v_li)
   ,.lce_data_cmd_ready_o(lce_data_cmd_rdy_lo)

   ,.lce_data_cmd_o(lce_data_cmd_lo)
   ,.lce_data_cmd_v_o(lce_data_cmd_v_lo)
   ,.lce_data_cmd_ready_i(lce_data_cmd_rdy_li)

   ,.proc_cfg_i(proc_cfg)

   ,.timer_int_i(timer_int)
   ,.software_int_i(software_int)
   ,.external_int_i(external_int)

   ,.cmt_rd_w_v_o(cmt_rd_w_v)
   ,.cmt_rd_addr_o(cmt_rd_addr)
   ,.cmt_mem_w_v_o(cmt_mem_w_v)
   ,.cmt_mem_addr_o(cmt_mem_addr)
   ,.cmt_mem_op_o(cmt_mem_op)
   ,.cmt_data_o(cmt_data)
   );

if (trace_p)
  begin : fi1
    bp_be_trace_replay_gen 
     #(.vaddr_width_p(vaddr_width_p)
       ,.paddr_width_p(paddr_width_p)
       ,.asid_width_p(asid_width_p)
       ,.trace_ring_width_p(trace_ring_width_p)
       )
     be_trace_gen
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
    
       ,.cmt_rd_w_v_i(cmt_rd_w_v)
       ,.cmt_rd_addr_i(cmt_rd_addr)
       ,.cmt_mem_w_v_i(cmt_mem_w_v)
       ,.cmt_mem_addr_i(cmt_mem_addr)
       ,.cmt_mem_op_i(cmt_mem_op)
       ,.cmt_data_i(cmt_data)
                
       ,.data_o(tr_data_li)
       ,.v_o(tr_v_li)
       ,.ready_i(tr_ready_lo)
       );
            
    bsg_fsb_node_trace_replay 
     #(.ring_width_p(trace_ring_width_p)
       ,.rom_addr_width_p(trace_rom_addr_width_p)
       )
     be_trace_replay 
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(1'b1)
                        
       ,.v_i(tr_v_li)
       ,.data_i(tr_data_li)
       ,.ready_o(tr_ready_lo)
                      
       ,.v_o()
       ,.data_o()
       ,.yumi_i(1'b0)
                      
       ,.rom_addr_o(tr_rom_addr_li)
       ,.rom_data_i(tr_rom_data_lo)
                      
       ,.done_o(test_done)
       ,.error_o()
       );
    
    bp_trace_rom 
     #(.width_p(trace_ring_width_p+4)
       ,.addr_width_p(trace_rom_addr_width_p)
       )
     trace_rom 
      (.addr_i(tr_rom_addr_li)
       ,.data_o(tr_rom_data_lo)
       );
  end // fi1
else
  begin : fi2
    assign test_done = 1'b0;
  end // fi2

bsg_fifo_1r1w_rolly 
 #(.width_p(fe_queue_width_lp)
   ,.els_p(16)
   ,.ready_THEN_valid_p(1)
   )
 fe_queue_fifo
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.clr_v_i(fe_queue_clr)
   ,.ckpt_v_i(fe_queue_dequeue)
   ,.roll_v_i(fe_queue_rollback)

   ,.data_i(fe_fe_queue)
   ,.v_i(fe_fe_queue_v)
   ,.ready_o(fe_fe_queue_rdy)

   ,.data_o(be_fe_queue)
   ,.v_o(be_fe_queue_v)
   ,.yumi_i(be_fe_queue_rdy)
   );

bsg_fifo_1r1w_small 
 #(.width_p(fe_cmd_width_lp)
   ,.els_p(8)
   ,.ready_THEN_valid_p(1)
   )
 fe_cmd_fifo
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
                      
   ,.data_i(be_fe_cmd)
   ,.v_i(be_fe_cmd_v)
   ,.ready_o(be_fe_cmd_rdy)
                
   ,.data_o(fe_fe_cmd)
   ,.v_o(fe_fe_cmd_v)
   ,.yumi_i(fe_fe_cmd_rdy)
   );

bp_be_mock_fe
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
 
   ,.boot_rom_els_p(boot_rom_els_p)
   ,.boot_rom_width_p(boot_rom_width_p)
   )
 fe
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.fe_cmd_i(fe_fe_cmd)
   ,.fe_cmd_v_i(fe_fe_cmd_v)
   ,.fe_cmd_rdy_o(fe_fe_cmd_rdy)

   ,.fe_queue_o(fe_fe_queue)
   ,.fe_queue_v_o(fe_fe_queue_v)
   ,.fe_queue_rdy_i(fe_fe_queue_rdy)

   ,.boot_rom_addr_o(irom_addr)
   ,.boot_rom_data_i(irom_data)
   );

bp_boot_rom 
 #(.width_p(boot_rom_width_p)
   ,.addr_width_p(lg_boot_rom_els_lp)
   )
 irom  
  (.addr_i(irom_addr)
   ,.data_o(irom_data)
   );

/* TODO: Replace with mock cce, once available */
logic [num_cce_p-1:0][mem_cce_resp_width_lp-1:0] mem_resp;
logic [num_cce_p-1:0] mem_resp_v;
logic [num_cce_p-1:0] mem_resp_ready;

logic [num_cce_p-1:0][mem_cce_data_resp_width_lp-1:0] mem_data_resp;
logic [num_cce_p-1:0] mem_data_resp_v;
logic [num_cce_p-1:0] mem_data_resp_ready;

logic [num_cce_p-1:0][cce_mem_cmd_width_lp-1:0] mem_cmd;
logic [num_cce_p-1:0] mem_cmd_v;
logic [num_cce_p-1:0] mem_cmd_yumi;

logic [num_cce_p-1:0][cce_mem_data_cmd_width_lp-1:0] mem_data_cmd;
logic [num_cce_p-1:0] mem_data_cmd_v;
logic [num_cce_p-1:0] mem_data_cmd_yumi;

bp_me_top 
 #(.cfg_p(cfg_p))
 me
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.lce_req_i(lce_cce_req)
   ,.lce_req_v_i(lce_cce_req_v)
   ,.lce_req_ready_o(lce_cce_req_rdy)

   ,.lce_resp_i(lce_cce_resp)
   ,.lce_resp_v_i(lce_cce_resp_v)
   ,.lce_resp_ready_o(lce_cce_resp_rdy)        

   ,.lce_data_resp_i(lce_cce_data_resp)
   ,.lce_data_resp_v_i(lce_cce_data_resp_v)
   ,.lce_data_resp_ready_o(lce_cce_data_resp_rdy)

   ,.lce_cmd_o(cce_lce_cmd)
   ,.lce_cmd_v_o(cce_lce_cmd_v)
   ,.lce_cmd_ready_i(cce_lce_cmd_rdy)

   ,.lce_data_cmd_i(lce_data_cmd_lo)
   ,.lce_data_cmd_v_i(lce_data_cmd_v_lo)
   ,.lce_data_cmd_ready_o(lce_data_cmd_rdy_li)

   ,.lce_data_cmd_o(lce_data_cmd_li)
   ,.lce_data_cmd_v_o(lce_data_cmd_v_li)
   ,.lce_data_cmd_ready_i(lce_data_cmd_rdy_lo)

   ,.cce_inst_boot_rom_addr_o(cce_inst_boot_rom_addr)
   ,.cce_inst_boot_rom_data_i(cce_inst_boot_rom_data)

   ,.mem_resp_i(mem_resp)
   ,.mem_resp_v_i(mem_resp_v)
   ,.mem_resp_ready_o(mem_resp_ready)

   ,.mem_data_resp_i(mem_data_resp)
   ,.mem_data_resp_v_i(mem_data_resp_v)
   ,.mem_data_resp_ready_o(mem_data_resp_ready)

   ,.mem_cmd_o(mem_cmd)
   ,.mem_cmd_v_o(mem_cmd_v)
   ,.mem_cmd_yumi_i(mem_cmd_yumi)

   ,.mem_data_cmd_o(mem_data_cmd)
   ,.mem_data_cmd_v_o(mem_data_cmd_v)
   ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi)

   );

for (genvar i = 0; i < num_cce_p; i++) begin
bp_cce_inst_rom
  #(.width_p(`bp_cce_inst_width)
    ,.addr_width_p(cce_instr_ram_addr_width_lp)
    )
  cce_inst_rom
   (.addr_i(cce_inst_boot_rom_addr)
    ,.data_o(cce_inst_boot_rom_data)
    );

bp_mem
  #(.num_lce_p(num_lce_p)
    ,.num_cce_p(num_cce_p)
    ,.paddr_width_p(paddr_width_p)
    ,.lce_assoc_p(lce_assoc_p)
    ,.block_size_in_bytes_p(cce_block_width_p/8)
    ,.lce_sets_p(lce_sets_p)
    ,.lce_req_data_width_p(dword_width_p)
    ,.mem_els_p(mem_els_p)
    ,.boot_rom_width_p(cce_block_width_p)
    ,.boot_rom_els_p(boot_rom_els_p)
  )
  bp_mem
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_i(mem_cmd[i])
   ,.mem_cmd_v_i(mem_cmd_v[i])
   ,.mem_cmd_yumi_o(mem_cmd_yumi[i])

   ,.mem_data_cmd_i(mem_data_cmd[i])
   ,.mem_data_cmd_v_i(mem_data_cmd_v[i])
   ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi[i])

   ,.mem_resp_o(mem_resp[i])
   ,.mem_resp_v_o(mem_resp_v[i])
   ,.mem_resp_ready_i(mem_resp_ready[i])

   ,.mem_data_resp_o(mem_data_resp[i])
   ,.mem_data_resp_v_o(mem_data_resp_v[i])
   ,.mem_data_resp_ready_i(mem_data_resp_ready[i])

   ,.boot_rom_addr_o(mrom_addr[i])
   ,.boot_rom_data_i(mrom_data[i])
   );

bp_boot_rom 
 #(.width_p(boot_rom_width_p)
   ,.addr_width_p(lg_boot_rom_els_lp)
   ) 
 me_boot_rom 
  (.addr_i(mrom_addr[i])
   ,.data_o(mrom_data[i])
   );
end

logic booted;

localparam max_instr_cnt_lp    = 2**30-1;
localparam lg_max_instr_cnt_lp = `BSG_SAFE_CLOG2(max_instr_cnt_lp);
logic [lg_max_instr_cnt_lp-1:0] instr_cnt;

  bsg_counter_clear_up
   #(.max_val_p(max_instr_cnt_lp)
     ,.init_val_p(0)
     )
   instr_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(cmt_rd_w_v | cmt_mem_w_v)

     ,.count_o(instr_cnt)
     );

localparam max_clock_cnt_lp    = 2**30-1;
localparam lg_max_clock_cnt_lp = `BSG_SAFE_CLOG2(max_clock_cnt_lp);
logic [lg_max_clock_cnt_lp-1:0] clock_cnt;

  bsg_counter_clear_up
   #(.max_val_p(max_clock_cnt_lp)
     ,.init_val_p(0)
     )
   clock_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(~booted)
     ,.up_i(1'b1)

     ,.count_o(clock_cnt)
     );

assign timer_int    = '0 & (clock_cnt == 10000);
assign software_int = '0 & (clock_cnt == 20000);
assign external_int = '0 & (clock_cnt == 30000);
   
always_ff @(posedge clk_i)
  begin
    if (reset_i)
        booted <= 1'b0;
    else 
      begin
        booted <= booted | fe_fe_queue_v; // Booted when we fetch the first instruction
      end
  end

always_ff @(posedge clk_i) 
  begin
    if (test_done) 
      begin
        $display("Test PASSed! Clocks: %d Instr: %d mIPC: %d", clock_cnt, instr_cnt, (1000*instr_cnt) / clock_cnt);
        $finish;
      end
  end

endmodule : testbench

