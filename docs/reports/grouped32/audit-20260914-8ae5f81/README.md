# Grouped32 baseline checkpoint audit

These reports audit the synthesized design recorded in
[the baseline synthesis evidence](../synth-20260914-8ae5f81/README.md). They do
not include the subsequent descriptor pipeline or CDC repairs. The checkpoint
SHA256 is in `manifest.json`; its working-tree build provenance and revision
stamp limitations are unchanged from the baseline.

All 12 requested Vivado reports completed, and the detached launcher returned
zero. Larger reports are losslessly gzip-compressed for repository storage.
`SHA256SUMS` verifies the published files; `manifest.json` also records the
uncompressed report hashes. For example:

```sh
sha256sum -c SHA256SUMS
gzip -dc cdc.rpt.gz | less
```

The hierarchy confirms four `afe_grouped_selftrigger_island` instances, eight
`afe_stc3_stream_serializer` instances, 32 `stc3_frame_source` instances and
four `xxv_ethernet_0` PHY instances. No native `stc3_record_builder` remains in
the active hardware. All 32 URAM primitives use `frontend_clock` on their
shared clock pin. The high-fanout net named `adc_reset_s_reg[7]_69` is a clock
alias driven by the frontend MMCM clock buffer; it is not reset driving clock
pins.

The DRC report has 867 warnings and no errors. Most warnings concern DSP input
pipelining. This synthesis-only DRC result is not implementation qualification.
CDC and methodology still have critical findings, including missing or
incoherent control/status synchronization and unsafe completion-flag exceptions.
Raw CDC counts include repeated memory/configuration paths and need structural
review; they are not counts of independent defects.

**CDC coverage limitation:** this run used Vivado's original 100,000 clock-pair
reporting threshold. The launcher warns that the `clk_pl_0` to
`frontend_clock` pair was truncated. Subsequent runs of
`scripts/verification/audit_synth_checkpoint.tcl` request 1,000,000. This report
must not be treated as a complete CDC audit.

`check_timing.rpt` identifies eight no-clock PS EMIO pins, 54 inputs without
delays and 51 outputs without delays. Forty-five inputs are AFE DDR capture
lanes. The AFE input min/max bounds remain unset in the board manifest; no
numbers were invented to satisfy the report. Other uncovered interfaces need
device timing/board bounds or documented asynchronous/static treatment.

Next qualification gates and outstanding work are tracked in
[the implementation plan](../../../grouped32-timing-closure-plan.md).
