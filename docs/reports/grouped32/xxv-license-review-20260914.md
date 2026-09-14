# XXV Ethernet license check for the pinned d1d07ac implementation

The K26C implementation from commit `d1d07ac` uses four XXV Ethernet PHY
paths generated from a project-level IP. During IP output-product generation and `synth_design`,
Vivado 2026.1 reports that `xxv_ethernet_0` is locked because mandatory
licenses are unavailable. It specifically reports the
`xxv_eth_mac_pcs@2026.06`, `xxv_eth_basekr@2026.06`, and
`xxv_tsn_802d1cm@2026.06` feature keys as unlicensed. Vivado warns that license
checkpoints may prevent use of this IP in some tool flows. A successful RTL
synthesis alone will not establish a usable firmware bundle.

The job uses `LM_LICENSE_FILE=2100@xilinx-lic` and Vivado's own log confirms
checkout of the `Synthesis` feature for `xck26`. A direct FlexNet query at
2026-09-14 15:30 America/Denver showed the license server and `xilinxd`
daemon up, with a checked-out `Synthesis` v2026.07 feature. Queries for
`xxv_eth_mac_pcs` and `xxv_eth_basekr` returned an empty feature-usage section.
These queries do not by themselves prove the server has no applicable alternate
entitlement, but they agree with Vivado's explicit locked-IP finding.

Reproduction (the installed `lmutil` has an unavailable LSB interpreter on this
host, so invoke it through the ordinary ELF loader):

```sh
/lib64/ld-linux-x86-64.so.2 \
  /opt/Xilinx/2026.1/Vivado/bin/unwrapped/lnx64.o/lmutil \
  lmstat -f xxv_eth_mac_pcs -c 2100@xilinx-lic
/lib64/ld-linux-x86-64.so.2 \
  /opt/Xilinx/2026.1/Vivado/bin/unwrapped/lnx64.o/lmutil \
  lmstat -f xxv_eth_basekr -c 2100@xilinx-lic
```

Keep the four Hermes PHY paths in the design. Resolve the IP entitlement or
provide an authorized build environment before claiming bitstream/artifact
qualification. Continue the current implementation run for timing evidence
unless Vivado stops it.
