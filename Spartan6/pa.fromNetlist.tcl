
# PlanAhead Launch Script for Post-Synthesis pin planning, created by Project Navigator

create_project -name Spartan6 -dir "G:/Facultad/Trabajo Final/Spartan6/planAhead_run_3" -part xc6slx9tqg144-2
set_property design_mode GateLvl [get_property srcset [current_run -impl]]
set_property edif_top_file "G:/Facultad/Trabajo Final/Spartan6/fx2lp_interface_top.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {G:/Facultad/Trabajo Final/Spartan6} }
set_param project.pinAheadLayout  yes
set_property target_constrs_file "fx2lp_interface_top.ucf" [current_fileset -constrset]
add_files [list {fx2lp_interface_top.ucf}] -fileset [get_property constrset [current_run]]
link_design
