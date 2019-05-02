
module bp_me_lce_data_resp_router
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )
   
   , parameter x_cord_width_p = "inv"
   , parameter y_cord_width_p = "inv"

   , localparam dirs_lp = 5

   , localparam max_num_flit_p = bp_data_resp_num_flit_gp
   , localparam len_width_lp=`BSG_SAFE_CLOG2(max_num_flit_p)
   , localparam max_payload_width_lp=lce_cce_data_resp_width_lp
   , localparam max_packet_width_lp=
       (x_cord_width_p+y_cord_width_p+len_width_lp+max_payload_width_lp)
   , localparam router_data_width_lp=
       (max_packet_width_lp/max_num_flit_p)+((max_packet_width_lp%max_num_flit_p) == 0 ? 0 : 1)
   , localparam payload_offset_lp=(x_cord_width_p+y_cord_width_p+len_width_lp)
   )
  (input clk_i
   , input reset_i

   , input [x_cord_width_p-1:0] my_x_i
   , input [y_cord_width_p-1:0] my_y_i

   , input [dirs_lp-1:0][lce_cce_data_resp_width_lp-1:0] lce_data_resp_i
   , input [dirs_lp-1:0]                            lce_data_resp_v_i
   , output [dirs_lp-1:0]                           lce_data_resp_ready_o

   , output [dirs_lp-1:0][lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
   , output [dirs_lp-1:0]                            lce_data_resp_v_o
   , input [dirs_lp-1:0]                             lce_data_resp_ready_i
   );

logic [dirs_lp-1:0][router_data_width_lp-1:0] wh_lce_data_resp_li;
logic [dirs_lp-1:0]                           wh_lce_data_resp_v_li, wh_lce_data_resp_ready_lo;
logic [dirs_lp-1:0][router_data_width_lp-1:0] wh_lce_data_resp_lo;
logic [dirs_lp-1:0]                           wh_lce_data_resp_v_lo, wh_lce_data_resp_ready_li;

for (genvar i = 0; i < dirs_lp; i++)
  begin : rof2
    logic [max_packet_width_lp-1:0] lce_data_resp_pkt_li, lce_data_resp_pkt_lo;

    bp_me_network_pkt_encode_data_resp
     #(.num_cce_p(num_cce_p)
       ,.num_lce_p(num_lce_p)
       ,.paddr_width_p(paddr_width_p)
       ,.block_size_in_bits_p(cce_block_width_p)
       ,.max_num_flit_p(max_num_flit_p)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       )
     data_resp_enc
      (.payload_i(lce_data_resp_i[i])
       ,.packet_o(lce_data_resp_pkt_li)
       );

    bsg_wormhole_router_adapter_in
     #(.max_num_flit_p(max_num_flit_p)
       ,.max_payload_width_p(max_payload_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       )
     data_resp_wh_adapter_in
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.data_i(lce_data_resp_pkt_li)
       ,.v_i(lce_data_resp_v_i[i])
       ,.ready_o(lce_data_resp_ready_o[i])

       ,.data_o(wh_lce_data_resp_li[i])
       ,.v_o(wh_lce_data_resp_v_li[i])
       ,.ready_i(wh_lce_data_resp_ready_lo[i])
       );

    bsg_wormhole_router_adapter_out
     #(.max_num_flit_p(max_num_flit_p)
       ,.max_payload_width_p(max_payload_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       )
     data_resp_wh_adapter_out
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.data_i(wh_lce_data_resp_lo[i])
       ,.v_i(wh_lce_data_resp_v_lo[i])
       ,.ready_o(wh_lce_data_resp_ready_li[i])

       ,.data_o(lce_data_resp_pkt_lo)
       ,.v_o(lce_data_resp_v_o[i])
       ,.ready_i(lce_data_resp_ready_i[i])
       );

    assign lce_data_resp_o[i] = lce_data_resp_pkt_lo[payload_offset_lp+:max_payload_width_lp];
  end

    bsg_wormhole_router
     #(.width_p(router_data_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ,.len_width_p(len_width_lp)
       ,.enable_2d_routing_p(1)
       ,.enable_yx_routing_p(1)
       ,.header_on_lsb_p(1)
       )
     data_resp_wh_router
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.local_x_cord_i(my_x_i)
       ,.local_y_cord_i(my_y_i)

       ,.data_i(wh_lce_data_resp_li)
       ,.valid_i(wh_lce_data_resp_v_li)
       ,.ready_o(wh_lce_data_resp_ready_lo)

       ,.data_o(wh_lce_data_resp_lo)
       ,.valid_o(wh_lce_data_resp_v_lo)
       ,.ready_i(wh_lce_data_resp_ready_li)
       );

endmodule : bp_me_lce_data_resp_router

