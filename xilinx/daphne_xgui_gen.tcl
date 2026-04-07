# create XGUI file generator
# describes the proper ipgui commands in order to properly modify parameters from the IP
# this is not the best solution at the moment,
# so it hopes for DAPHNE to not have more parameters in the near future!
# <daniel.avila@eia.edu.co - daniel.avila.gomez@cern.ch>

# ------------------------------------------------------------------------------------------------------------------------------------------------
# UPDATE: For the newer version of the integrated robust self trigger, the threshold parameter of the IP is eliminated
# old lines removed: 
# LINE 29: ipgui::add_param $IPINST -name "threshold" -parent ${Page_0}
# LINES 82 TO 89: 
# proc update_PARAM_VALUE.threshold { PARAM_VALUE.threshold } {
# 	# Procedure called to update threshold when any of the dependent parameters in the arguments change
# }
#
# proc validate_PARAM_VALUE.threshold { PARAM_VALUE.threshold } {
# 	# Procedure called to validate threshold
# 	return true
# }
# LINES 127 TO 130:
# proc update_MODELPARAM_VALUE.threshold { MODELPARAM_VALUE.threshold PARAM_VALUE.threshold } {
# 	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
# 	set_property value [get_property value ${PARAM_VALUE.threshold}] ${MODELPARAM_VALUE.threshold}
# }
# ------------------------------------------------------------------------------------------------------------------------------------------------

# create the folder where the file will be located
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
if {![info exists daphne_ip_root]} {
    source -notrace [file join $script_dir "daphne_board_env.tcl"]
    set daphne_ip_root [file normalize [daphne_get_env_or_default DAPHNE_IP_REPO_ROOT [file join $repo_root "ip_repo" "daphne_ip"]]]
}
if {![info exists daphne_ip_xgui_file]} {
    set daphne_ip_xgui_file [daphne_get_env_or_default DAPHNE_IP_XGUI_FILE "daphne_selftrigger_top_v1_0.tcl"]
}
set xgui_dir [file join $daphne_ip_root "xgui"]
file mkdir $xgui_dir

# set the file path
set xgui_file_path [file join $xgui_dir $daphne_ip_xgui_file]

# create/open the file 
set fileId [open $xgui_file_path "w"]

# write the gui content
puts $fileId {# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "version" -parent ${Page_0}
  ipgui::add_param $IPINST -name "link_id" -parent ${Page_0}
  ipgui::add_param $IPINST -name "slot_id" -parent ${Page_0}
  ipgui::add_param $IPINST -name "crate_id" -parent ${Page_0}
  ipgui::add_param $IPINST -name "detector_id" -parent ${Page_0}
  ipgui::add_param $IPINST -name "version_id" -parent ${Page_0}


}

proc update_PARAM_VALUE.version { PARAM_VALUE.version } {
	# Procedure called to update version when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.version { PARAM_VALUE.version } {
	# Procedure called to validate version
	return true
}

proc update_PARAM_VALUE.link_id { PARAM_VALUE.link_id } {
	# Procedure called to update link_id when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.link_id { PARAM_VALUE.link_id } {
	# Procedure called to validate link_id
	return true
}

proc update_PARAM_VALUE.slot_id { PARAM_VALUE.slot_id } {
	# Procedure called to update slot_id when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.slot_id { PARAM_VALUE.slot_id } {
	# Procedure called to validate slot_id
	return true
}

proc update_PARAM_VALUE.crate_id { PARAM_VALUE.crate_id } {
	# Procedure called to update crate_id when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.crate_id { PARAM_VALUE.crate_id } {
	# Procedure called to validate crate_id
	return true
}

proc update_PARAM_VALUE.detector_id { PARAM_VALUE.detector_id } {
	# Procedure called to update detector_id when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.detector_id { PARAM_VALUE.detector_id } {
	# Procedure called to validate detector_id
	return true
}

proc update_PARAM_VALUE.version_id { PARAM_VALUE.version_id } {
	# Procedure called to update version_id when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.version_id { PARAM_VALUE.version_id } {
	# Procedure called to validate version_id
	return true
}


proc update_MODELPARAM_VALUE.version { MODELPARAM_VALUE.version PARAM_VALUE.version } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.version}] ${MODELPARAM_VALUE.version}
}

proc update_MODELPARAM_VALUE.link_id { MODELPARAM_VALUE.link_id PARAM_VALUE.link_id } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.link_id}] ${MODELPARAM_VALUE.link_id}
}

proc update_MODELPARAM_VALUE.slot_id { MODELPARAM_VALUE.slot_id PARAM_VALUE.slot_id } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.slot_id}] ${MODELPARAM_VALUE.slot_id}
}

proc update_MODELPARAM_VALUE.crate_id { MODELPARAM_VALUE.crate_id PARAM_VALUE.crate_id } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.crate_id}] ${MODELPARAM_VALUE.crate_id}
}

proc update_MODELPARAM_VALUE.detector_id { MODELPARAM_VALUE.detector_id PARAM_VALUE.detector_id } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.detector_id}] ${MODELPARAM_VALUE.detector_id}
}

proc update_MODELPARAM_VALUE.version_id { MODELPARAM_VALUE.version_id PARAM_VALUE.version_id } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.version_id}] ${MODELPARAM_VALUE.version_id}
}
}

# close the file
close $fileId
