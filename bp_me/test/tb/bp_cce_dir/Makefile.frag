TB_PARAMS=-pvalue+num_way_groups_p=64 \
					 -pvalue+num_lce_p=1 \
					 -pvalue+lce_assoc_p=8 \
					 -pvalue+tag_width_p=44

HDL_DEFINES=+define+BSG_CORE_CLOCK_PERIOD=10

HDL_PARAMS=$(DUT_PARAMS) $(TB_PARAMS) $(HDL_DEFINES)

TOP_MODULE=bp_cce_dir
