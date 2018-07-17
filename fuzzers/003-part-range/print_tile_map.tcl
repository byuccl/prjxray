# Checks to see if a design is open or not
if {[catch {get_design} err]} {
    create_project -force -part $::env(XRAY_PART) design design
    link_design
}



# Set a global mapping between specific Tile types and a single character
set tile_type_char_map {}

# These are "NULL" tiles (place holders to get the 2D grid to fit)
lappend tile_type_char_map {{ NULL } {.}}
# Dedicated NULL tiles (provide space in bitstream for parts with certain resources)
lappend tile_type_char_map {{ PCIE_NULL } {,}}
# Break tiles
lappend tile_type_char_map {{ VBRK VFRAME VBRK_EXT HCLK_VBRK HCLK_VFRAME } {-}}
# Feedthrough tiles
lappend tile_type_char_map {{ INT_FEEDTHRU_1 INT_FEEDTHRU_2 HCLK_FEEDTHRU_1 HCLK_FEEDTHRU_2 } {F}}
# Clock tiles
lappend tile_type_char_map {{ CMT_PMV CMT_PMV_L CMT_TOP_R_UPPER_T CMT_TOP_L_UPPER_T CMT_TOP_L_UPPER_B CMT_TOP_R_UPPER_B CMT_TOP_R_LOWER_T CMT_TOP_R_LOWER_B CLK_FEED CMT_FIFO_R CMT_FIFO_L HCLK_CMT HCLK_CMT_L CLK_BUFG_REBUF CLK_BUFG_TOP_R CLK_BUFG_BOT_R CLK_HROW_TOP_R CMT_TOP_L_LOWER_T CMT_TOP_L_LOWER_B CLK_MTBF2 CLK_PMV2 CLK_PMV2_SVT CLK_PMVIOB CLK_PMV CLK_HROW_BOT_R } {K}}
# Termination tiles
lappend tile_type_char_map {{ T_TERM_INT B_TERM_INT TERM_CMT CLK_TERM L_TERM_INT R_TERM_INT_GTX HCLK_TERM HCLK_TERM_GTX BRKH_B_TERM_INT BRKH_TERM_INT R_TERM_INT INT_INTERFACE_L INT_INTERFACE_PSS_L } {T}}
# I/O tiles
lappend tile_type_char_map {{ LIOB33_SING LIOI3_SING  LIOB33 LIOI3 LIOI3_TBYTESRC LIOI3_TBYTETERM HCLK_IOB HCLK_IOI3 RIOB33_SING RIOI3_SING RIOI3 RIOB33 RIOI3_TBYTESRC RIOI3_TBYTETERM RIOI_SING LIOI_SING LIOB18_SING RIOB18_SING RIOB18 RIOI_TBYTE_SRC RIOI_TBYTETERM HCLK_IOI RIOI LIOI LIOB18 RIOI_TBYTESRC LIOI_TBYTESRC LIOI_TBYTETERM } {O} }
# Interconnect tiles
lappend tile_type_char_map {{ INT_L INT_R } {I} }
# CLB tiles
lappend tile_type_char_map {{ CLBLL_L CLBLL_R CLBLM_R CLBLM_L  } {C} }
# Interface tiles (interface between resource and I/O tile)
lappend tile_type_char_map {{ IO_INT_INTERFACE_L IO_INT_INTERFACE_R INT_INTERFACE_R INT_INTERFACE_L BRAM_INT_INTERFACE_L BRAM_INT_INTERFACE_R GTP_INT_INTERFACE GTP_INT_INTERFACE_R GTP_INT_INTERFACE_L PCIE_INT_INTERFACE_R PCIE_INT_INTERFACE_L PCIE_INT_INTERFACE_R  GTH_INT_INTERFACE } {N} }
# BRAM tiles
lappend tile_type_char_map {{ BRAM_L BRAM_R } {B} }
# DSP tiles
lappend tile_type_char_map {{ DSP_L DSP_R } {D} }
# GTx tiles
lappend tile_type_char_map {{ GTP_CHANNEL_3 GTP_CHANNEL_2 GTP_CHANNEL_1 GTP_COMMON GTP_CHANNEL_0 GTX_INT_INTERFACE GTX_CHANNEL_0 GTX_CHANNEL_1 GTX_CHANNEL_2 GTX_CHANNEL_3 GTX_COMMON GTH_CHANNEL_3 GTH_CHANNEL_2 GTH_CHANNEL_1 GTH_CHANNEL_0 GTH_COMMON GTP_INT_INT_TERM_L GTP_INT_INT_TERM_R GTP_CHANNEL_3_MID_LEFT GTP_CHANNEL_3_MID_RIGHT GTP_MID_CHANNEL_STUB GTP_CHANNEL_2_MID_LEFT GTP_CHANNEL_2_MID_RIGHT GTP_COMMON_MID_LEFT GTP_MID_COMMON_STUB GTP_COMMON_MID_RIGHT GTP_CHANNEL_1_MID_LEFT GTP_CHANNEL_1_MID_RIGHT GTP_CHANNEL_0_MID_RIGHT GTP_CHANNEL_0_MID_LEFT } {G} }
# Horizontal clock tiles
lappend tile_type_char_map {{ HCLK_L HCLK_R HCLK_FIFO_L HCLK_CLB HCLK_BRAM HCLK_DSP_R HCLK_DSP_L HCLK_L_BOT_UTURN HCLK_R_BOT_UTURN HCLK_GTX HCLK_FEEDTHRU_1_PELE HCLK_INT_INTERFACE HCLK_L_TOP_UTURN HCLK_R_TOP_UTURN } {H} }
# Break tiles (Between horizontal clock regions)
lappend tile_type_char_map {{ BRKH_INT BRKH_CLB BRKH_BRAM BRKH_DSP_L BRKH_DSP_R BRKH_GTX BRKH_CMT BRKH_CLK BRKH_INT_PSS } {R} }
# PCI tiles
lappend tile_type_char_map {{ PCIE_BOT PCIE_TOP PCIE3_INT_INTERFACE_R PCIE3_INT_INTERFACE_L PCIE3_RIGHT PCIE3_TOP_RIGHT PCIE3_BOT_RIGHT } {E}}
# Processor tiles
lappend tile_type_char_map {{ PSS4 PSS3 PSS2 PSS1 PSS0 } {P}}
# Monitor and configuration tiles
lappend tile_type_char_map {{ MONITOR_TOP MONITOR_MID MONITOR_BOT CFG_CENTER_TOP  CFG_CENTER_MID CFG_CENTER_BOT MONITOR_TOP_FUJI2 MONITOR_BOT_FUJI2 MONITOR_MID_FUJI2 MONITOR_TOP_PELE1 MONITOR_MID_PELE1 MONITOR_BOT_PELE1 	CFG_SECURITY_TOP_PELE1 CFG_SECURITY_MID_PELE1 CFG_SECURITY_BOT_PELE1 } {M} }

# Takes a tile type and returns a single character used to represent the tile type
proc get_tile_type_char { tile_type } {
    global tile_type_char_map
    set tile_char {?}
    foreach tile_map $tile_type_char_map {
	set matching_words [lindex $tile_map 0]
	if [expr [lsearch $matching_words $tile_type] > -1] {
	    set tile_char [lindex $tile_map 1]
	    break;
	}
    }
    return $tile_char
}

# from the X/Y coordinates of a slice, this will find the tile and return the grid X,Y locations
proc get_tile_grid_loc { slice_x slice_y } {
    set slice_name [format "SLICE_X%dY%d" $slice_x $slice_y]
    set slice [get_sites $slice_name]
    set tile [get_tiles -of $slice]
    puts $tile
    set x_loc [get_property GRID_POINT_X $tile]
    set y_loc [get_property GRID_POINT_Y $tile]
    lappend coords $x_loc $y_loc
    return $coords
}


# Computes the number of tile columns and rows in the device. It returns a list
# of two numbers: {x y} where x is the number of columns in the device and
# y is the number of rows in the device.
proc get_tile_size {} {

    # Find last column
    set cur_column 0
    set cur_row 0

    set valid 1
    while {$valid} {
	# get the tile at the current location
	set cur_tile [get_tiles -quiet -filter "GRID_POINT_X == $cur_column && GRID_POINT_Y == $cur_row"]
	# see if the tile exists. If not, exit
	if {[ catch {get_property NAME $cur_tile } err]}  {
	    set valid 0
	} else {
	    set cur_column [expr $cur_column + 1]
	}
    }
    # The current column points to an invalid column (the column after the last
    # valid column). Since the first column starts at column 0, this number
    # is the number of valid columns in the device.
    set number_of_columns [expr $cur_column ]
    
    set valid 1
    set cur_column 0
    while {$valid} {
	# get the tile at the current location
	set cur_tile [get_tiles -quiet -filter "GRID_POINT_X == $cur_column && GRID_POINT_Y == $cur_row"]
	# see if the tile exists. If not, exit
	if {[  catch {get_property NAME $cur_tile } err]}  {
	    set valid 0
	} else {
	    set cur_row [expr $cur_row + 1]
	}
    }
    set number_of_rows [expr $cur_row ]

    return [list $number_of_columns $number_of_rows]
}

# This will search through the columns of a row to find the valid
# clb/interconnect pairs in the row.
proc find_clb_interconnect_pairs { row } {
    
    set cur_column 0
    set seek_int_clb SEEK_INT_CLB   ;# Seeking either a 
    set found_clb_l FOUND_CLB_L
    set found_int_r FOUND_INT_R
    
    set cur_state $seek_int_clb
    set valid 1
    set last_tile_type {}
    set tile_type {}

    set match_list {}
    
    while {$valid} {
	set match 0
	# get the tile at the current location
	set cur_tile [get_tiles -quiet -filter "GRID_POINT_X == $cur_column && GRID_POINT_Y == $row"]
	# see if the tile exists. If not, exit
	if {[ catch {get_property NAME $cur_tile } err]}  {
	    if {$cur_column == 0} {
		# if we get a bad tile at the first column then we have a bad row
		return {}
	    }
	    set valid 0
	    break
	}
	set last_tile_type $tile_type
	set tile_type [get_property TILE_TYPE $cur_tile]
	#puts "$cur_column - $tile_type"
	if {$cur_state == $seek_int_clb} {
	    # Seeking either a CLB_L or a INT_R
	    if {$tile_type == "CLBLL_L" || $tile_type == "CLBLM_L"} {
		set cur_state $found_clb_l
		#puts "\tFound CLB_L"
	    } elseif {$tile_type == "INT_R" } {
		set cur_state $found_int_r
		#puts "\tFound INT_R"
	    } elseif {$tile_type == "CLBLL_R" || $tile_type == "CLBLM_R"} {
		#puts "\tError: unexpected CLB_R found"
	    }
	} elseif {$cur_state == $found_clb_l} {
	    # found a CLB_L on the previous column. This must be a INT_L
	    set cur_state $seek_int_clb
	    if {$tile_type == "INT_L" } {
		#puts "\tFound INT_L - match"
		set match 1
	    } else {
		#puts "\tError: expecting INT_L"
	    }
	} elseif {$cur_state == $found_int_r} {
	    # Found a INT_R, looking for a CLB_R next
	    set cur_state $seek_int_clb
	    if {$tile_type == "CLBLL_R" || $tile_type == "CLBLM_R"} {
		set match 1
		#puts "\tFound CLB_R - match"
	    } else {
		# Nothing: it is ok to have other tiles after an INT_L
	    }
	} else {
	    set cur_state $seek_int_clb
	    #puts "\tShouldn't get here"
	}	

	if {$match} {
	    set match_columns [list [expr $cur_column -1]  $cur_column ]
	    set match_types [list $last_tile_type $tile_type ]
	    set match_info [list $match_columns $match_types]
	    lappend match_list $match_info
	    #puts "$match_info"
	}
	set cur_column [expr $cur_column + 1]
    }
    #puts $match_list
    return $match_list
}

# Look at the linear list of classified tile columns and group these columns together
# into configuration bitstream columns.
proc convert_tile_columns_to_config_columns { column_list } {
    
    set cur_column 0
    
    set init_state INIT_STATE
    set init_io_state INIT_IO_STATE
    set unknown_i_state UNKNOWN_I_STATE
    
    set cur_state $init_state
    set init_column -1
    
    #set last_tile_type {}
    #set tile_type {}
    #set match_list {}

    for {set i 0} {$i < [llength $column_list]} {incr i} {
	set column [lindex $column_list $i]

	# Initial state - starting a new search sequence
	if {$cur_state == $init_state} {
	    if {$column == "O"} {
		set cur_state $init_io_state
		set init_column $i
	    } elseif {$column == "I"} {
		set cur_state $unknown_i_state
		set init_column $i
	    }
	    
	    # Initial I/O state - looking for the end
	} elseif {$cur_state == $init_io_state} {
	    if {$column == "T" || $column == "N" || $column == "O"} {
		# Stay in this state, building an I/O column
	    } elseif {$column == "I"} {
		# an I is the last column of a left IO state
		lappend config_column $init_column $i IO
		set cur_state $init_state
	    }
	    
	} elseif {$cur_state == $unknown_i_state} {
	    if {$column == "N"} {
		# Stay in this state, building on an unknown I starting state
	    } elseif {$column == "I"} {
		# an I is the last column of a left IO state
		lappend config_column $init_column $i IO
		set cur_state $init_state
	    }
	} else {
	    puts "Warning: Unknown State: $cur_state"
	}
    }
    
    while {$valid} {

	set last_tile_type $tile_type
	set tile_type [get_property TILE_TYPE $cur_tile]
	#puts "$cur_column - $tile_type"
	if {$cur_state == $seek_int_clb} {
	    # Seeking either a CLB_L or a INT_R
	    if {$tile_type == "CLBLL_L" || $tile_type == "CLBLM_L"} {
		set cur_state $found_clb_l
		#puts "\tFound CLB_L"
	    } elseif {$tile_type == "INT_R" } {
		set cur_state $found_int_r
		#puts "\tFound INT_R"
	    } elseif {$tile_type == "CLBLL_R" || $tile_type == "CLBLM_R"} {
		#puts "\tError: unexpected CLB_R found"
	    }
	} elseif {$cur_state == $found_clb_l} {
	    # found a CLB_L on the previous column. This must be a INT_L
	    set cur_state $seek_int_clb
	    if {$tile_type == "INT_L" } {
		#puts "\tFound INT_L - match"
		set match 1
	    } else {
		#puts "\tError: expecting INT_L"
	    }
	} elseif {$cur_state == $found_int_r} {
	    # Found a INT_R, looking for a CLB_R next
	    set cur_state $seek_int_clb
	    if {$tile_type == "CLBLL_R" || $tile_type == "CLBLM_R"} {
		set match 1
		#puts "\tFound CLB_R - match"
	    } else {
		# Nothing: it is ok to have other tiles after an INT_L
	    }
	} else {
	    set cur_state $seek_int_clb
	    #puts "\tShouldn't get here"
	}	

	if {$match} {
	    set match_columns [list [expr $cur_column -1]  $cur_column ]
	    set match_types [list $last_tile_type $tile_type ]
	    set match_info [list $match_columns $match_types]
	    lappend match_list $match_info
	    #puts "$match_info"
	}
	set cur_column [expr $cur_column + 1]
    }
    #puts $match_list
    return $match_list
}

proc find_clb_interconnect_pairs_in_device { } {
    set valid 1
    # The first CLBs will be on row 1
    set cur_row 1
    while {$valid} {
	set cur_tile [get_tiles -quiet -filter "GRID_POINT_X == 0 && GRID_POINT_Y == $cur_row"]
	if { [  catch {get_property NAME $cur_tile } err] } {
	    # end of valid rows. Exit
	    set valid 0
	    break
	} else {
	    puts "Row $cur_row: [find_clb_interconnect_pairs $cur_row]]"
	    set cur_row [expr $cur_row + 52]
	}
    }
    
}

# Look at all of the tile types in a column of tiles and classify it as a single
# tile. Many columns have multiple tile types and this procedure figures out which
# tile type dominates.
proc classify_column { col row_start row_end } {

    # Sets the priority of columns. Those later in the list have a higher priority

    lappend priority ? - T N M F E O K I C

    set column "."
    for {set i $row_start} {$i <= $row_end} {incr i} {
	set cur_tile [get_tiles -quiet -filter "GRID_POINT_X == $col && GRID_POINT_Y == $i"]
	set tile_type [get_property TILE_TYPE $cur_tile]
	set tile_type_char [get_tile_type_char $tile_type  ]

	set column_priority 0
	set tile_priority 0
	if {$tile_type_char == "." || $tile_type_char == "," || $tile_type_char == "H"} {
	    # Ignore these tiles: they have no impact on classification
	} else {
	    # Need to process these tiles
	    if {$column == "."} {
		# if the column is not classified, classify it	
		set column $tile_type_char
	    } elseif {$column != $tile_type_char} {
		# Handle the special cases when the current type doesn't match the classification
		set column_priority [lsearch $priority $column]
		set tile_priority [lsearch $priority $tile_type_char]
		if {$column_priority == -1 || $tile_priority == -1} {
		    puts "Warning: no priority difference between $column and $tile_type_char"
		}
		if {$tile_priority > $column_priority} {
		    set column $tile_type_char
		}
		
	    }
	}
	#puts -nonewline "$i/$column/$tile_type_char/$column_priority/$tile_priority "
	
	
    }
    #puts "Done=$column"
    return $column
}

# 
proc classify_rows { row_start row_end {write_fd stdout} } {
    set columns {}
    set valid 1
    set cur_column 0

    set column_types {}
    
    # iterate over all columns
    while {$valid == 1} {

	# Get the tile at the current location (note we don't know if the current
	# location is even valid)
	set cur_tile [get_tiles -quiet -filter "GRID_POINT_X == $cur_column && GRID_POINT_Y == $row_start"]

	# see if this is a valid tile. If not, the previous column was the
	# last column in the row. Also, check to see if we have reached the
	# column after the last one we want to print.
	if { [  catch {get_property NAME $cur_tile } err] } {
	    set valid 0
	    break
	} else {
	    set column [classify_column $cur_column $row_start $row_end]
	    puts -nonewline $write_fd "$column"
	    lappend column_types $column
	    set cur_column [expr $cur_column + 1]
	}
    }
    #puts $write_fd $column_types
    #puts $write_fd ""
    return $column_types
}

proc classify_device_rows { {write_fd stdout} } {
    set valid 1
    set cur_row 1
    
    while {$valid == 1} {

	# Get the tile at the current location (note we don't know if the current
	# location is even valid)
	#puts "Testing row $cur_row"
	set cur_tile [get_tiles -quiet -filter "GRID_POINT_X == 0 && GRID_POINT_Y == $cur_row"]

	# see if this is a valid tile. If not, there are no more rows
	if { [  catch {get_property NAME $cur_tile } err] } {
	    set valid 0
	    break
	} else {
	    set end_row [expr $cur_row+50]
	    puts -nonewline $write_fd "Rows $cur_row-$end_row:"
	    classify_rows $cur_row $end_row $write_fd
	    puts $write_fd ""
	    set cur_row [expr $end_row+2]
	}
    }
    
}

# Procedure for checking arguements and boudning them
proc bound_range { min max input default_min } {

    if {$input == -1} {
	if { $default_min } { set result $min } else { set result $max }
    } else {
	if { $input < $min } {
	    set result $min
	} elseif { $input > $max } {
	    set result $max
	} else {
	    set result $input
	}
    }
    return $result
}


proc create_tile_array {} {
    foreach tile [get_tiles] {
	set x_loc [get_property GRID_POINT_X $tile]
	set y_loc [get_property GRID_POINT_Y $tile]
    }
}

proc print_tile_map { {col_min -1} {row_min -1} {col_max -1} {row_max -1} {write_fd stdout} } {


    # Determine tile size of device
    set tile_size [get_tile_size]
    set tile_columns [lindex $tile_size 0]
    set tile_rows [lindex $tile_size 1]
    puts "Device Tile Dimensions: ($tile_columns X $tile_rows)"

    # determine the range of tiles to print

    # Start column
    set last_column [expr $tile_columns -1 ]
    set last_row [expr $tile_rows-1]
    set col_start [bound_range 0 $last_column $col_min 1]
    set col_end [bound_range 0 $last_column $col_max 0]
    set row_start [bound_range 0 $last_row $row_min 1]
    set row_end [bound_range 0 $last_row $row_max 0]
    #puts "Requset print range of ($col_min,$row_min) to ($col_max,$row_max)"
    puts "Will print range of ($col_start,$row_start) to ($col_end,$row_end)"

    # print top column number
    set pretext "    "   ;# four spaces: 3 for digits and one for :
    # Hundreds digit
    puts -nonewline $write_fd $pretext
    for {set i $col_start} { $i <= $col_end} { incr i} {
	set char [expr ($i/100) % 100]
	puts -nonewline $write_fd $char
    }
    puts $write_fd ""
    # Tens digit
    puts -nonewline $write_fd $pretext
    for {set i $col_start} { $i <= $col_end} { incr i} {
	set char [expr ($i/10) % 10]
	puts -nonewline $write_fd $char
    }
    puts $write_fd ""
    # Ones digit
    puts -nonewline $write_fd $pretext
    for {set i $col_start} { $i <= $col_end} { incr i} {
	set char [expr $i % 10]
	puts -nonewline $write_fd $char
    }
    puts $write_fd ""
    
    # Groupings
    # Each of these tiles types are organized together and will be represented
    # with the same character.


    global tile_type_char_map

    set cur_row $row_start
    set cur_column $col_start
    set device_done 0
    set verbose 1

    set unknown_tile_types {}
    
    # Iterate through all columns and rows to map device tiles
    # Iterate over all columns in a row and then move up a row.
    while {$device_done != 1} {

	#puts -nonewline "($cur_column,$cur_row) "

	# Get the tile at the current location (note we don't know if the current
	# location is even valid)
	set cur_tile [get_tiles -quiet -filter "GRID_POINT_X == $cur_column && GRID_POINT_Y == $cur_row"]

	# see if this is a valid tile. If not, the previous column was the
	# last column in the row. Also, check to see if we have reached the
	# column after the last one we want to print.
	if { [  catch {get_property NAME $cur_tile } err] || $cur_column == $col_end+1} {

	    # Is this the last row?
	    if [expr $cur_row == $row_end] {
		set device_done 1
		puts $write_fd "" ; # last line
	    } else {
		# go to next row
		set cur_row [expr $cur_row+1]
		set cur_column $col_start
		puts $write_fd "" ; # new line
	    }
	} else {
	    # Valid tile. Print character

	    # Print the row number when in first column
	    if [expr $cur_column == 0] {
		set row_num [format "%3d" $cur_row]
		puts -nonewline $write_fd $row_num
		puts -nonewline $write_fd ":"
	    }
	    
	    # Print character for tile
	    #set tile_name [get_property NAME $cur_tile]
	    set tile_type [get_property TILE_TYPE $cur_tile]

	    set tile_char [get_tile_type_char $tile_type]
	    # set tile_char {?}
	    # foreach tile_map $tile_type_char_map {
	    # 	set matching_words [lindex $tile_map 0]
	    # 	if [expr [lsearch $matching_words $tile_type] > -1] {
	    # 	    set tile_char [lindex $tile_map 1]
	    # 	    break;
	    # 	}
	    # }

	    # see if the tile type is unknown. If so, save it for printing.
	    if {$tile_char == "?"} {
		# see if the unkown tile type has already been added
		if [expr [lsearch $unknown_tile_types $tile_type] == -1] {
		    # it has not been added. Add it		
		    lappend unknown_tile_types $tile_type
		    puts "Unknown type: $tile_type"
		}
	    }
	    
	    # Print tile type character
	    puts -nonewline $write_fd $tile_char
	    set cur_column [expr $cur_column + 1 ]
	}
    }

    puts $write_fd "Key:"
    foreach tile_char $tile_type_char_map {
	puts -nonewline $write_fd "[lindex $tile_char 1]:\t"
	set matching_words [lindex $tile_char 0]
	foreach word $matching_words {
	    puts -nonewline $write_fd "$word "
	}
	puts $write_fd ""
    }

    set num_unknown_tile_types [llength unknown_tile_types]
    if {$num_unknown_tile_types > 0} {
    	puts $write_fd "\nUnknown Tile Types: (?) - $num_unknown_tile_types"
    	foreach unknown_tile $unknown_tile_types {
    	    puts $write_fd "\t$unknown_tile"
    	}
    } else {
    	puts $write_fd "\nNo Unknown Tile Types found"
    }

}

#classify_rows 0 51
#classify_device_rows
#find_clb_interconnect_pairs_in_device
#find_clb_interconnect_pairs 1
#print_tile_map  0 0 50 10 

set fp [open "device_rows.txt" "w"]
classify_device_rows $fp
close $fp

set fp [open "tile_map.txt" "w"]
print_tile_map -1 -1 -1 -1 $fp
close $fp
