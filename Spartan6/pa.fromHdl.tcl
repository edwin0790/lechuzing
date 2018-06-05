
# PlanAhead Launch Script for Pre-Synthesis Floorplanning, created by Project Navigator

create_project -name Spartan6 -dir "G:/Facultad/Trabajo Final/Spartan6/planAhead_run_4" -part xc6slx9tqg144-2
set_param project.pinAheadLayout yes
set srcset [get_property srcset [current_run -impl]]
set_property target_constrs_file "fx2lp_interface_top.ucf" [current_fileset -constrset]
set hdlfile [add_files [list {ipcore_dir/clk_wiz_v3_6.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {fi_ram_memory.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {fx2lp_interface_top.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set_property top fx2lp_interface_top $srcset
add_files [list {fx2lp_interface_top.ucf}] -fileset [get_property constrset [current_run]]
open_rtl_design -part xc6slx9tqg144-2
