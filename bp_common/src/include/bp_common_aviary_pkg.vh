
package bp_common_aviary_pkg;
  `include "bp_common_aviary_defines.vh"

  // Suitably high enough to not run out of configs.
  localparam max_cfgs    = 128;
  localparam lg_max_cfgs = `BSG_SAFE_CLOG2(max_cfgs);

  localparam bp_proc_param_s bp_inv_cfg_p = 
    '{default: "inv"};

  localparam bp_proc_param_s bp_half_core_cfg_p = 
    '{num_core: 1
      ,num_cce: 1
      ,num_lce: 1

      ,vaddr_width: 39
      ,paddr_width: 39
      ,asid_width : 1
      
      ,branch_metadata_fwd_width: 27
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2
      
      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,num_cce_instr_ram_els: 256

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 2

      ,dword_width      : 64
      ,instr_width      : 32
      ,reg_addr_width   : 5
      ,page_offset_width: 12
      };

  localparam bp_proc_param_s bp_single_core_cfg_p = 
    '{num_core: 1
      ,num_cce: 1
      ,num_lce: 2

      ,vaddr_width: 39
      ,paddr_width: 39
      ,asid_width : 1
      
      ,branch_metadata_fwd_width: 27
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2
      
      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,num_cce_instr_ram_els: 256

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 2

      ,dword_width      : 64
      ,instr_width      : 32
      ,reg_addr_width   : 5
      ,page_offset_width: 12
      };

  localparam bp_proc_param_s bp_dual_core_cfg_p = 
    '{num_core: 2
      ,num_cce: 2
      ,num_lce: 4
      
      ,vaddr_width: 39
      ,paddr_width: 39
      ,asid_width : 1
      
      ,branch_metadata_fwd_width: 27
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2
      
      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,num_cce_instr_ram_els: 256

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 2

      ,dword_width      : 64
      ,instr_width      : 32
      ,reg_addr_width   : 5
      ,page_offset_width: 12
      };

  localparam bp_proc_param_s bp_quad_core_cfg_p = 
    '{num_core: 4
      ,num_cce: 4
      ,num_lce: 8
      
      ,vaddr_width: 39
      ,paddr_width: 39
      ,asid_width : 1
      
      ,branch_metadata_fwd_width: 27
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2
      
      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,num_cce_instr_ram_els: 256

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 2

      ,dword_width      : 64
      ,instr_width      : 32
      ,reg_addr_width   : 5
      ,page_offset_width: 12
      };

  localparam bp_proc_param_s bp_oct_core_cfg_p = 
    '{num_core: 8
      ,num_cce: 8
      ,num_lce: 16
      
      ,vaddr_width: 39
      ,paddr_width: 39
      ,asid_width : 1
      
      ,branch_metadata_fwd_width: 27
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2
      
      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,num_cce_instr_ram_els: 256

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 2

      ,dword_width      : 64
      ,instr_width      : 32
      ,reg_addr_width   : 5
      ,page_offset_width: 12
      };

  typedef enum bit [lg_max_cfgs-1:0] 
  {
    e_bp_oct_core_cfg     = 5
    ,e_bp_quad_core_cfg   = 4
    ,e_bp_dual_core_cfg   = 3
    ,e_bp_single_core_cfg = 2
    ,e_bp_half_core_cfg   = 1
    ,e_bp_inv_cfg         = 0
  } bp_cfg_e;

  parameter bp_proc_param_s [max_cfgs-1:0] all_cfgs_gp =
  {
    bp_oct_core_cfg_p
    ,bp_quad_core_cfg_p
    ,bp_dual_core_cfg_p
    ,bp_single_core_cfg_p
    ,bp_half_core_cfg_p
    ,bp_inv_cfg_p
  };

endpackage : bp_common_aviary_pkg

