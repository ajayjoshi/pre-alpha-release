TRACE_REPLAY ?= 0

DUT_PARAMS = -pvalue+trace_p=$(TRACE_REPLAY)         \
             -pvalue+calc_debug_p=1

TB_PARAMS  = -pvalue+trace_ring_width_p=129          \
             -pvalue+trace_rom_addr_width_p=32

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

