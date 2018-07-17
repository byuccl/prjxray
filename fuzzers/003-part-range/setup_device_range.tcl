create_project -force -part $::env(XRAY_PART) design design

read_verilog ../top.v
synth_design -top top
