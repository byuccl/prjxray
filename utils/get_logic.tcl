#  get_logic.tcl
#
#  Gets the bel to logical function mapping for all instantiated cells

# There's two option here for how I could represent the output:
#  1) I could have a whole recursive function that goes into each cell
#     and then recursively goes into child cells if it's not a leaf and
#     only prints pin mappings if the current cell is a leaf
#  2) I could also just go through the entire list of cells, and check
#     to see if the cell has a corresponding bel, and, if so, pring mappings.
#
# I think I'll go with option 2 for now, because I think 1 is overkill. It
#   could potentially be useful to have a representation of the hierarchy, but
#   I don't think I need it for the pin mappings (plus I could get that from
#   the netlist)

#open the output file
set outfile [open "logic_map.json" w]

set cells [get_cells -hierarchical *]

#puts $outfile "\{ \"cells\" :"
puts $outfile "\{"

# Make a list of cells that actually have bels 
set cells_w_bels {}
foreach current_cell $cells {
    if { [llength [get_bels -of $current_cell]] != 0} {
	lappend cells_w_bels $current_cell
    }
    if { [llength [get_bels -of $current_cell]] > 1} {
	puts "WARNING: cell $current_cell has more than one bel!"
    }
}

puts "processing [llength $cells_w_bels] items"
set cidx 0

foreach current_cell $cells_w_bels {
    puts $cidx
    #puts $current_cell
    puts -nonewline $outfile "  "
    #if {$cidx == 0} {puts -nonewline $outfile "\[" }

    set cellname [get_property NAME $current_cell]
    puts $outfile "\"$cellname\":"

    set pidx 0
    foreach cell_pin [get_pins -of $current_cell] {
	#puts $cell_pin
	puts -nonewline $outfile "    "
	if {$pidx == 0} { puts -nonewline $outfile "\{" }
	set pin_name [get_property NAME $cell_pin]
	if {[llength [get_bel_pins -of $cell_pin]] == 0} {
	    set bel_pin_name ""
	} else {
	    set bel_pin_name [get_property NAME [get_bel_pins -of $cell_pin]]
	}
	puts -nonewline $outfile " \"$pin_name\" : \"$bel_pin_name\" "
	if {$pidx == [llength [get_pins -of $current_cell]] - 1} {
	    puts -nonewline $outfile "\}"
	} else { puts -nonewline $outfile ",\n"}
	#puts -nonewline $outfile "\n"
	incr pidx
    }

    #puts -nonewline $outfile "\}"
    
    if {$cidx == [llength $cells_w_bels] - 1} {
	#puts -nonewline $outfile "\]"
    } else {puts -nonewline $outfile ","}
    puts -nonewline $outfile "\n"
    
    incr cidx
} 

puts $outfile "}"

close $outfile
