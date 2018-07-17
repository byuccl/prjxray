
# Iterate over the tiles to find the CLB rows in the device

# Get all of the CLB tiles and put them in a list
set clb_tiles [get_tiles -pattern "CLB*"]
# indicates how many CLB tiles there are
llength $clb_tiles
# Get the first tile in the list
set first_tile [lindex $clb_tiles 0]
# List the property names of this tile (should be the same for all tiles)
list_property $first_tile


set max_x -1
set max_y -1
set min_x 10000000
set min_y 10000000
set columns {}
set rows {}
foreach tile $clb_tiles {
    set grid_x [get_property GRID_POINT_X $tile]
    set grid_y [get_property GRID_POINT_Y $tile]
    if [expr $grid_x < $min_x] { set min_x $grid_x }
    if [expr $grid_x > $max_x] { set max_x $grid_x } 
    if [expr $grid_y < $min_y] { set min_y $grid_y }
    if [expr $grid_y > $max_y] { set max_y $grid_y }
    # see if the column is in the list of columns
    if [expr [lsearch $columns $grid_x] < 0 ] {lappend columns $grid_x}
    if [expr [lsearch $rows $grid_y ] < 0] {lappend rows $grid_y}
    set name [get_property NAME $tile]
#    puts "$name $grid_x $grid_y"
}

# Identify row groups
lsort -integer $rows
set row_groups {}
# indicates the first row is the start of a new group
set new_group 1  
foreach row $rows {

    # see if we are starting a new group
    if [expr $new_group] {
	set start_group_row $row
	set new_group 0
	# Check for end of row group
    } elseif [expr $row == $start_group_row + 50] { 
	# end of row group
	set end_group_row $row
	lappend row_groups [list $start_group_row  $end_group_row]
	set new_group 1
    } else {
	# At this point, we are not the first or last row of a row group.
	# Check this row number to make sure it is consistent with row groups
	# (i.e., it is consecutive or the row after the ECC word).
	if [expr $row != $last_row + 1 && $row != $start_group_row + 26] {
	    puts "Warning: non consecutive row at row $row"
	}
    }
    set last_row $row
}
puts $row_groups

set diff_x [expr $max_x-$min_x+1]
set diff_y [expr $max_y-$min_y+1]
puts "Min: ($min_x,$min_y) Max: ($max_x,$max_y) Diff: ($diff_x,$diff_y)"
set num_columns [llength $columns]
set num_rows [llength $rows]
puts "Columns ($num_columns): $columns"
puts "Rows ($num_rows): $rows"






# Command reference:
#  list_property (object): lists the valid property key names of an object
#  get_property (name) (object): returns the property value for property keyed
#                                with 'name' for object 'object'
#  list_property_value: lists valid values for a property
#  report_property (object): lists the property name and value for all
#                            properties of an object.

# Interesting commands:
#  get_parts  (list of all parts that is searchable)
# 
