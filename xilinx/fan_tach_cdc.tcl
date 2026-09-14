# The two fan tachometer pins are unrelated to the 100 MHz monitor clock.
# fanmon first captures each input in an ASYNC_REG pair before debouncing.
# Exclude only the asynchronous arrival at each first-stage D pin; the
# synchronizer's second stage and all RPM/debounce logic remain timed.
set fan_tach_first_stages [get_pins -hier -quiet -filter {
    NAME =~ *fanmon*_inst/tach_meta_reg/D
}]
if {[llength $fan_tach_first_stages] != 2} {
    error "Expected two fan tachometer first-stage D pins, found [llength $fan_tach_first_stages]"
}
set_false_path -to $fan_tach_first_stages
