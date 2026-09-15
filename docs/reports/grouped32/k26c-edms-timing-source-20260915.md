# K26C PCB timing source

The board owner identified CERN EDMS navigator document `101959906` as the
source hierarchy for K26C PCB design data:

<https://edms.cern.ch/ui/#!master/navigator/document?D:101959906:101959906:subDocs>

The link is now the authoritative starting point for choosing the released
assembly revision and its matching PCB layout or timing report. The EDMS page
loads as a JavaScript application and its subdocuments require CERN account
access; this build environment could not inspect their titles, revisions or
attachments. No revision or delay value has been inferred from the URL alone.

AFE timing sign-off still needs the matching released board revision and the
following routed values or per-net flight times from that EDMS hierarchy:

- FPGA-to-AFE sampling-clock trace delay and skew;
- AFE-to-FPGA data-lane trace delays and lane-to-lane skew;
- AFE-to-FPGA FCLK trace delay and its skew relative to each data lane;
- the units, stack-up/propagation model and min/max or tolerance basis used by
  the PCB report.

Combine those PCB values with the AFE5808A's output timing for the confirmed
16-bit, 62.5 MHz mode before enabling `DAPHNE_AFE_CAPTURE_INPUT_DELAY_ENABLE`.
Until the released revision and numerical bounds are extracted, the current
internal routed timing result does not qualify the external LVDS interface.
