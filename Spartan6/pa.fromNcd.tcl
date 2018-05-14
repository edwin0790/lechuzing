
# PlanAhead Launch Script for Post PAR Floorplanning, created by Project Navigator

create_project -name Spartan6 -dir "G:/Facultad/Trabajo Final/Spartan6/planAhead_run_1" -part xc6slx9tqg144-2
set srcset [get_property srcset [current_run -impl]]
set_property design_mode GateLvl $srcset
set_property edif_top_file "G:/Facultad/Trabajo Final/Spartan6/fx2lp_interface_top.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {G:/Facultad/Trabajo Final/Spartan6} }
set_property target_constrs_file "fx2lp_interface_top.ucf" [current_fileset -constrset]
add_files [list {fx2lp_interface_top.ucf}] -fileset [get_property constrset [current_run]]
link_design
read_xdl -file "G:/Facultad/Trabajo Final/Spartan6/fx2lp_interface_top.ncd"
if {[catch {read_twx -name results_1 -file "G:/Facultad/Trabajo Final/Spartan6/fx2lp_interface_top.twx"} eInfo]} {
   puts "WARNING: there was a problem importing \"G:/Facultad/Trabajo Final/Spartan6/fx2lp_interface_top.twx\": $eInfo"
}
