
# PlanAhead Launch Script for Post-Synthesis pin planning, created by Project Navigator

create_project -name Cyclon6 -dir "/home/lechuzin/Facultad/Trabajo Final/lechuzing/Cyclon6/planAhead_run_4" -part xc6slx9tqg144-2
set_property design_mode GateLvl [get_property srcset [current_run -impl]]
set_property edif_top_file "/home/lechuzin/Facultad/Trabajo Final/lechuzing/Cyclon6/fx2lp_interface_top.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {/home/lechuzin/Facultad/Trabajo Final/lechuzing/Cyclon6} }
set_param project.pinAheadLayout  yes
set_property target_constrs_file "fx2lp_interface_top.ucf" [current_fileset -constrset]
add_files [list {fx2lp_interface_top.ucf}] -fileset [get_property constrset [current_run]]
link_design
