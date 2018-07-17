create_project -force -part $::env(XRAY_PART) design design
read_verilog ../top.v
synth_design -top top

#open_project ./design/design.xpr

set cur_row 0
set cur_column 0
set device_done 0
set verbose 1

set ignore_tile_types [list NULL VBRK VFRAME VBRK_EXT]

# Iterate through all columns and rows to map device tiles
# Iterate over all columns in a row and then move up a row.
while {$device_done != 1} {

    puts -nonewline "($cur_column,$cur_row) "

    # If the current row is zero then set the current column stack to -1
    # (indicating there are no stacks at this column)
    if [expr $cur_row == 0] {
	set current_column_stack($cur_column) -1
    }
    
    # Get the tile at the current location (note we don't know if the current
    # location is even valid)
    set cur_tile [get_tiles -quiet -filter "GRID_POINT_X == $cur_column && GRID_POINT_Y == $cur_row"]

    # see if this is a valid tile. If not, the previous column was the last column
    # in the row.
    if {[  catch {get_property NAME $cur_tile } err]} {
	# If this is the first column of a row then the previous row was the
	# last valid row. Device is done.
	if [expr $cur_column == 0] {
	    set device_done 1
	    puts "Invalid - end of device"
	} else {
	    # go to next row
	    set cur_row [expr $cur_row+1]
	    set cur_column 0
	    puts "Invalid - end of row"
	}
    } else {

	# Valid tile

	set cur_tile_type [get_property TILE_TYPE $cur_tile]

	# Check to see if current tile type is ignored
	if [expr [lsearch $ignore_tile_types $cur_tile_type] > -1] {
	    puts -nonewline "**IGNORE** "
	    # Check to see if there was a stack building in this column.
	    # If so, print the stack and reset
	    if [expr $current_column_stack($cur_column) != -1] {
		puts -nonewline "Ending Stack: $current_column_stack($cur_column) to "
		set top_stack [expr $cur_row - 1]
		puts $top_stack
		# Print stack
		for {set i $current_column_stack($cur_column)} {$i <= $top_stack} {incr i} {
		}
		set current_column_stack($cur_column) -1
	    }
	} else {
	    # non ignore tile
	    if [expr $current_column_stack($cur_column) == -1] {
		puts -nonewline "Starting new Stack "
		set current_column_stack($cur_column) $cur_row
		puts -nonewline $current_column_stack($cur_column)
	    }
	}

	puts -nonewline [get_property NAME $cur_tile]
	puts -nonewline " "
	puts -nonewline $cur_tile_type
	puts ""
	set cur_column [expr $cur_column + 1 ]

	
    }

    
}

#BRAM_INT_INTERFACE_L BRAM_INT_INTERFACE_R BRAM_L BRAM_R BRKH_BRAM BRKH_B_TERM_INT BRKH_CLB BRKH_CLK BRKH_CMT BRKH_DSP_L BRKH_DSP_R BRKH_GTX BRKH_INT BRKH_TERM_INT B_TERM_INT CFG_CENTER_BOT CFG_CENTER_MID CFG_CENTER_TOP CLBLL_L CLBLL_R CLBLM_L CLBLM_R CLK_BUFG_BOT_R CLK_BUFG_REBUF CLK_BUFG_TOP_R CLK_FEED CLK_HROW_BOT_R CLK_HROW_TOP_R CLK_MTBF2 CLK_PMV CLK_PMV2 CLK_PMV2_SVT CLK_PMVIOB CLK_TERM CMT_FIFO_L CMT_FIFO_R CMT_PMV CMT_PMV_L CMT_TOP_L_LOWER_B CMT_TOP_L_LOWER_T CMT_TOP_L_UPPER_B CMT_TOP_L_UPPER_T CMT_TOP_R_LOWER_B CMT_TOP_R_LOWER_T CMT_TOP_R_UPPER_B CMT_TOP_R_UPPER_T DSP_L DSP_R GTP_CHANNEL_0 GTP_CHANNEL_0_MID_LEFT GTP_CHANNEL_0_MID_RIGHT GTP_CHANNEL_1 GTP_CHANNEL_1_MID_LEFT GTP_CHANNEL_1_MID_RIGHT GTP_CHANNEL_2 GTP_CHANNEL_2_MID_LEFT GTP_CHANNEL_2_MID_RIGHT GTP_CHANNEL_3 GTP_CHANNEL_3_MID_LEFT GTP_CHANNEL_3_MID_RIGHT GTP_COMMON GTP_COMMON_MID_LEFT GTP_COMMON_MID_RIGHT GTP_INT_INTERFACE GTP_INT_INTERFACE_L GTP_INT_INTERFACE_R GTP_INT_INT_TERM_L GTP_INT_INT_TERM_R GTP_MID_CHANNEL_STUB GTP_MID_COMMON_STUB HCLK_BRAM HCLK_CLB HCLK_CMT HCLK_CMT_L HCLK_DSP_L HCLK_DSP_R HCLK_FEEDTHRU_1 HCLK_FEEDTHRU_2 HCLK_FIFO_L HCLK_GTX HCLK_INT_INTERFACE HCLK_IOB HCLK_IOI3 HCLK_L HCLK_L_BOT_UTURN HCLK_R HCLK_R_BOT_UTURN HCLK_TERM HCLK_TERM_GTX HCLK_VBRK HCLK_VFRAME INT_FEEDTHRU_1 INT_FEEDTHRU_2 INT_INTERFACE_L INT_INTERFACE_R INT_L INT_R IO_INT_INTERFACE_L IO_INT_INTERFACE_R LIOB33 LIOB33_SING LIOI3 LIOI3_SING LIOI3_TBYTESRC LIOI3_TBYTETERM L_TERM_INT MONITOR_BOT MONITOR_BOT_FUJI2 MONITOR_MID MONITOR_MID_FUJI2 MONITOR_TOP MONITOR_TOP_FUJI2 NULL PCIE_BOT PCIE_INT_INTERFACE_L PCIE_INT_INTERFACE_R PCIE_NULL PCIE_TOP RIOB33 RIOB33_SING RIOI3 RIOI3_SING RIOI3_TBYTESRC RIOI3_TBYTETERM R_TERM_INT R_TERM_INT_GTX TERM_CMT T_TERM_INT VBRK VBRK_EXT VFRAME

