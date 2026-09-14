# Clean Cooper build for 512-sample continuation

Connect using the requested Kerberos jump-host route:

```bash
ssh -J dunegpvm01 -K arroyave@cooper.dhcp.fnal.gov
```

Cooper was inspected on 2026-09-11. It has eight logical CPUs, 31 GiB RAM,
Vivado 2026.1 (SW build 6511674), Vitis 2026.1, SDTGen, DTC, FuseSoC and
tmux. Existing tmux sessions belong to earlier jobs and must be preserved.
Use four Vivado threads initially; check current memory and running jobs
before starting another implementation.

Build a committed revision from a local git bundle. Transfer the bundle into
a newly named directory below `/tmp/arroyave/work`, verify its SHA256 on both
hosts, clone it to a new `src` directory, and switch that clone to the exact
commit. This transfers tracked source and commit history without copying
`.Xil`, generated IP, checkpoints, or other build products from an old tree.
Do not synchronize subsequent source changes into a running build. Each new
candidate gets a new bundle, clean clone, and evidence directory.

Run the repository helper inside an independently named tmux session:

```bash
tmux new-session -d -s daphne-512-COMMIT \
  'bash /tmp/arroyave/work/RUN/src/scripts/remote/cooper_clean_build.sh /tmp/arroyave/work/RUN/src /tmp/arroyave/work/RUN/evidence > /tmp/arroyave/work/RUN/launcher.log 2>&1'
```

Replace `RUN` and `COMMIT` with the actual unique directory and revision.
The helper refuses a clone with pre-existing build state or modified tracked
source, records source and vendor-memory hashes, and runs the native Linux
implementation and overlay packaging chain. Its controlled PATH avoids the
unrelated PetaLinux SDK in the account's login environment. The build log,
tool version, exit status and start/finish times survive an SSH disconnect.
Git is available only through the SDK on this host, so the helper keeps the
SDK's `usr/bin` as a fallback after system directories. The helper checks
artifact presence and package checksums, but successful
execution alone is not timing qualification.

Review and retain the routed timing summary, utilization, DRC, methodology
and clock reports. Record setup/hold slack, all unconstrained-path warnings,
any failing DRC rules, and the exact source commit. Deliver the `.bit`,
`.bin`, `.xsa`, `.dtbo`, overlay zip, report set and checksums only after the
required checks pass. No device programming is part of this workflow.

The fresh baseline build uses commit
`7d5d3a64339c78cdf4a2052079300563bdde215e` in
`/tmp/arroyave/work/dsc512-base-20260911T133500Z/src`.
Its local source-bundle SHA256 is
`78e1f80a39127bc3c0e6596ab7a35b04ebfd71b093ae824363e5548574571369`.
The helper is supplied outside that baseline source tree, so the baseline
remains unchanged. Baseline measurements are comparison evidence and do not
qualify a continuation implementation.

The installed XPM memory source permits SDP UltraRAM with common clock,
`WRITE_MODE_B="read_first"`, `READ_LATENCY_B=1`, and `AUTO_SLEEP_TIME=0`.
Vendor checks at lines 625–634 require at least one read stage, prohibit
`no_change` for SDP UltraRAM, and require at least three stages only for
`write_first`. The baseline evidence records the installed vendor-file hash
and those checks.

## Vendor memory simulation

`scripts/remote/cooper_vendor_memory_sim.sh SOURCE_ROOT NEW_SIM_DIRECTORY`
compiles the installed AMD XPM VHDL component declarations and SystemVerilog
memory models into a simulation-local library. Explicit library mapping is
required because Cooper's default XSim configuration otherwise maps `xpm`
into the read-only tool installation. It then runs the real builder and
two-lane output mux with even and odd frame starts, verifies every ADC sample
in 30 consecutive packets per case, and checks boundary cases.

This passed for candidate `355376f` on 2026-09-11 in
`/tmp/arroyave/work/dsc512-cont-355376f-20260911/vendor-memory-sim-attempt02`.
The initial simulation attempt stopped before design compilation because of
the default library mapping; that failed attempt remains alongside the
successful one. This is a targeted gateware/vendor-model check. The broader
waveform simulator workload runs on the local workstation.

## Hierarchical resource evidence

After a synthesis or routed checkpoint is available, use
`scripts/remote/cooper_report_resources.tcl CHECKPOINT NEW_REPORT_DIRECTORY`
with Vivado batch mode. It produces total and hierarchical utilization plus
a TSV naming every BRAM/URAM primitive. These reports identify the actual
cost of the rings, packet stores and spy capture in the candidate instead of
inferring it from historical build totals.
