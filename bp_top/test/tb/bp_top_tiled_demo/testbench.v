/**
  *
  * testbench.v
  *
  */

module testbench
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   // Number of elements in the fake BlackParrot memory
   , parameter clock_period_in_ps_p = 1000
   , parameter prog_name_p = "prog.mem"
   , parameter dram_cfg_p  = "DDR2_micron_16M_8b_x8_sg3E.ini"
   , parameter dram_sys_cfg_p = "system.ini"
   , parameter dram_capacity_p = 16384

   // These should go away with the manycore bridge
   , localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)

   // Trace replay parameters
   , parameter trace_p                     = "inv"
   , parameter trace_ring_width_p          = "inv"
   , parameter trace_rom_addr_width_p      = "inv"
   , localparam trace_rom_data_width_lp    = trace_ring_width_p + 4
   )
  (input clk_i
   , input reset_i
   );

logic [num_cce_p-1:0][cce_instr_ram_addr_width_lp-1:0] cce_inst_boot_rom_addr;
logic [num_cce_p-1:0][`bp_cce_inst_width-1:0]          cce_inst_boot_rom_data;

logic [num_core_p-1:0][trace_ring_width_p-1:0] tr_data_i;
logic [num_core_p-1:0] tr_v_i, tr_ready_o;
logic [num_core_p-1:0] test_done;

logic [num_core_p-1:0][trace_rom_addr_width_p-1:0]  tr_rom_addr_i;
logic [num_core_p-1:0][trace_rom_data_width_lp-1:0] tr_rom_data_o;

logic [num_core_p-1:0]                              cmt_rd_w_v;
logic [num_core_p-1:0][rv64_reg_addr_width_gp-1:0]  cmt_rd_addr;
logic [num_core_p-1:0]                              cmt_mem_w_v;
logic [num_core_p-1:0][dword_width_p-1:0]           cmt_mem_addr;
logic [num_core_p-1:0][`bp_be_fu_op_width-1:0]      cmt_mem_op;
logic [num_core_p-1:0][dword_width_p-1:0]           cmt_data;

logic [num_cce_p-1:0][mem_cce_resp_width_lp-1:0] mem_resp;
logic [num_cce_p-1:0] mem_resp_v, mem_resp_ready;

logic [num_cce_p-1:0][mem_cce_data_resp_width_lp-1:0] mem_data_resp;
logic [num_cce_p-1:0] mem_data_resp_v, mem_data_resp_ready;

logic [num_cce_p-1:0][cce_mem_cmd_width_lp-1:0] mem_cmd;
logic [num_cce_p-1:0] mem_cmd_v, mem_cmd_yumi;

logic [num_cce_p-1:0][cce_mem_data_cmd_width_lp-1:0] mem_data_cmd;
logic [num_cce_p-1:0] mem_data_cmd_v, mem_data_cmd_yumi;

   wrapper
    #(.cfg_p(cfg_p)
      ,.trace_p(trace_p)
      )
    wrapper
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

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

      ,.timer_int_i(1'b0)
      ,.software_int_i(1'b0)
      ,.external_int_i(1'b0)

      ,.cmt_rd_w_v_o(cmt_rd_w_v)
      ,.cmt_rd_addr_o(cmt_rd_addr)
      ,.cmt_mem_w_v_o(cmt_mem_w_v)
      ,.cmt_mem_addr_o(cmt_mem_addr)
      ,.cmt_mem_op_o(cmt_mem_op)
      ,.cmt_data_o(cmt_data)
      );

   for (genvar i = 0; i < num_cce_p; i++) 
     begin : rof1
       bp_mem_dramsim2
        #(.mem_id_p(i)
          ,.clock_period_in_ps_p(clock_period_in_ps_p)
          ,.prog_name_p(prog_name_p)
          ,.dram_cfg_p(dram_cfg_p)
          ,.dram_sys_cfg_p(dram_sys_cfg_p)
          ,.dram_capacity_p(dram_capacity_p)
          ,.num_lce_p(num_lce_p)
          ,.num_cce_p(num_cce_p)
          ,.paddr_width_p(paddr_width_p)
          ,.lce_assoc_p(lce_assoc_p)
          ,.block_size_in_bytes_p(cce_block_width_p/8)
          ,.lce_sets_p(lce_sets_p)
          ,.lce_req_data_width_p(dword_width_p)
          )
        mem
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
          );

       bp_cce_inst_rom
        #(.width_p(`bp_cce_inst_width)
          ,.addr_width_p(cce_instr_ram_addr_width_lp)
          )
        cce_inst_rom
         (.addr_i(cce_inst_boot_rom_addr[i])
          ,.data_o(cce_inst_boot_rom_data[i])
          );
   end // rof1

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
      ,.up_i(|{cmt_rd_w_v | cmt_mem_w_v})

      ,.count_o(instr_cnt)
      );

localparam max_clock_cnt_lp    = 2**30-1;
localparam lg_max_clock_cnt_lp = `BSG_SAFE_CLOG2(max_clock_cnt_lp);
logic [lg_max_clock_cnt_lp-1:0] clock_cnt;
logic booted;

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

always_ff @(posedge clk_i)
  begin
    if (reset_i)
        booted <= 1'b0;
    else
      begin
        // This should simply be based on frozen signal
        booted <= 1'b1;
      end
   end 

always_ff @(posedge clk_i)
  begin
    if (&test_done)
      begin
        $display("Test PASSed! Clocks: %d Instr: %d mIPC: %d", clock_cnt, instr_cnt, (1000*instr_cnt) / clock_cnt);
        $finish(0);
      end
   end

endmodule : testbench
