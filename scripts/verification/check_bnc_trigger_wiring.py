#!/usr/bin/env python3
"""Execute both BD connection procedures with mocked Vivado connection APIs."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
STUBS = r"""
set connections {}
set properties {}
proc get_bd_ports {name} {return port/$name}
proc get_bd_pins {name} {return $name}
proc get_bd_intf_pins {name} {return $name}
proc daphne_bd_pin {cell name} {return $cell/$name}
proc daphne_bd_intf_pin {cell name} {return $cell/$name}
proc daphne_bd_net_label {cell name} {return ${cell}_$name}
proc connect_bd_intf_net {args} {}
proc connect_bd_net {args} {lappend ::connections $args}
proc create_bd_cell {args} {return [lindex $args end]}
proc set_property {args} {lappend ::properties $args}
"""
CHECK = r"""
set bnc_connections 0
set force_connections 0
foreach connection $connections {
    if {[lsearch -exact $connection port/trig_IN] >= 0} {
        incr bnc_connections
        if {[lsearch -exact $connection dut/trig_IN] < 0 ||
            [lsearch -exact $connection dut/FORCE_TRIG] >= 0} {
            error "BNC must connect only to the frontend trigger input"
        }
    }
    if {[lsearch -exact $connection dut/FORCE_TRIG] >= 0} {
        incr force_connections
        if {$connection ne {dut_legacy_force_zero/dout dut/FORCE_TRIG}} {
            error "Legacy software input is not tied to the zero constant"
        }
    }
}
if {$bnc_connections != 1 || $force_connections != 1} {
    error "Missing or duplicated trigger connections"
}
if {[lsearch -exact $properties {-dict {CONFIG.CONST_WIDTH 1 CONFIG.CONST_VAL 0} dut_legacy_force_zero}] < 0} {
    error "Legacy trigger constant is not one-bit zero"
}
puts "PASS: BNC isolated from software trigger input"
"""
for relative, procedure in (
    ("boards/k26c/bd_shell.tcl", "daphne_connect_board_user_ip"),
    ("xilinx/daphne_bd_gen.tcl", "daphne_connect_default_user_ip"),
):
    source = (ROOT / relative).read_text()
    match = re.search(r"^proc " + procedure + r" .*?^}\n", source, re.M | re.S)
    if match is None:
        raise RuntimeError(f"Missing procedure {procedure}")
    subprocess.run(["tclsh"], input="if {[catch {\n" + STUBS + match.group() + f"\n{procedure} dut\n" + CHECK + "\n} message]} {puts stderr $message; exit 1}\n",
                   text=True, check=True)
