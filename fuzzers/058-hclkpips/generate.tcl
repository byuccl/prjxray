create_project -force -part $::env(XRAY_PART) design design

read_verilog ../top.v
synth_design -top top

set_property -dict "PACKAGE_PIN $::env(XRAY_PIN_00) IOSTANDARD LVCMOS33" [get_ports i]
set_property -dict "PACKAGE_PIN $::env(XRAY_PIN_01) IOSTANDARD LVCMOS33" [get_ports o]

create_pblock roi
resize_pblock [get_pblocks roi] -add "$::env(XRAY_ROI)"

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.PERFRAMECRC YES [current_design]
set_param tcl.collectionResultDisplayLimit 0

place_design
route_design

write_checkpoint -force design.dcp

source ../../../utils/utils.tcl

if [regexp "_001$" [pwd]] {set tile [lindex [filter [roi_tiles] {TILE_TYPE == HCLK_L}] 0]}
if [regexp "_002$" [pwd]] {set tile [lindex [filter [roi_tiles] {TILE_TYPE == HCLK_R}] 0]}

set net [get_nets o_OBUF]
set pips [get_pips -of_objects $tile]

set num_pips_minus_1 [expr [llength $pips] - 1]
set failed_pip_routes {}

for {set i 0} {$i < [llength $pips]} {incr i} {
	set pip [lindex $pips $i]
    puts "**********************************************************" 
    puts "* Performing route $i (0 to $num_pips_minus_1) for pip:"
    puts "*   $pip"
    puts "**********************************************************" 
	set_property IS_ROUTE_FIXED 0 $net
	route_design -unroute -net $net
	set n1 [get_nodes -uphill -of_objects $pip]
	set n2 [get_nodes -downhill -of_objects $pip]
	route_via $net "$n1 $n2"
	write_checkpoint -force design_$i.dcp

    if { [ catch { write_bitstream -force design_$i.bit } err] } {

        puts "**********************************************************" 
	puts "*** Warning: write_bitstream failed for $pip"
	puts "* "
	puts "$err"
	puts "* "
	puts "* No output will be generated "
        puts "**********************************************************" 
	lappend failed_pip_routes $pip
	     
    } else {
	    
	set fp [open "design_$i.txt" w]
	puts $fp "$tile $pip"
	close $fp
    }

}



set num_failed_pips [llength unknown_tile_types]
if {$num_failed_pips > 0} {
    puts "\nFailed PIPs - $num_failed_pips"
    foreach failed_pip $num_failed_pips {
	puts "\t$failed_pip"
    }
} else {
    puts $write_fd "\nNo Failed pips"
}
