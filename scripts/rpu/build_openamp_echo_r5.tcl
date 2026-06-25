if {$argc < 2 || $argc > 3} {
    puts stderr "usage: build_openamp_echo_r5.tcl <xsa> <out-dir> ?processor?"
    exit 2
}

set xsa [file normalize [lindex $argv 0]]
set out_dir [file normalize [lindex $argv 1]]
set processor "psu_cortexr5_0"
if {$argc == 3} {
    set processor [lindex $argv 2]
}

file delete -force $out_dir
file mkdir $out_dir

set ws [file join $out_dir workspace]
set platform_name daphne_r5_platform
set domain_name daphne_r5_standalone
set app_name daphne_rpu_openamp_echo

setws $ws
repo -set /opt/Xilinx/Vitis/2024.1/data/embeddedsw

platform create -name $platform_name -hw $xsa -proc $processor -os standalone -out $ws -no-boot-bsp
platform active $platform_name
domain active standalone_domain
domain rename standalone_domain $domain_name
domain active $domain_name

bsp setlib -name xiltimer
bsp setlib -name libmetal
bsp setlib -name openamp
bsp write
platform generate

app create \
    -name $app_name \
    -platform $platform_name \
    -domain $domain_name \
    -sysproj ${app_name}_system \
    -template "OpenAMP echo-test"

app build -name $app_name

set elf [file join $ws $app_name "Debug" "${app_name}.elf"]
if {![file exists $elf]} {
    puts stderr "expected ELF not found: $elf"
    exit 1
}

file copy -force $elf [file join $out_dir "${app_name}.elf"]
puts [file join $out_dir "${app_name}.elf"]
