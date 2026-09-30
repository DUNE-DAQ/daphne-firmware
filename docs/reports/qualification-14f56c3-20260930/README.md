# DAPHNE-015 qualification of firmware 14f56c3

The exact HDL candidate 14f56c38ad0ce382b8261f059cc5af2405b8b2d5 was built
on Cooper from a fresh committed-source clone. Full build and packaging exited
0. All artifact checksums passed. Routed setup/hold/pulse-width slack:
+0.083/+0.010/+0.280 ns; no failing timing endpoints or unconstrained internal
endpoints. DRC reports warnings only, chiefly DSP input pipelining.
Formal policy HDL is unchanged from the 33 passing proof/cover jobs recorded
in ../trigger-selector-20260929; both BD BNC isolation checks and real board
interface elaboration passed for the corrected candidate.

Loaded on DAPHNE-015 with identity 0x014F56C3, ABI 2.0, variant 1. Both Hermes
physical links are configured, only link 0 receives. Software trigger commands
are generated directly in PS at 1 kHz; continuation is disabled and xcorr
threshold is 16 for acquisition. DAQ random trigger requests are 10 Hz.

Run 45324: 5,349,488 bytes, 109 trigger records, 9,344 waveform frames, 584
per channel 0–15 and 4,672 per source 800/801. Every record contains all 16
channels. All 584 event timestamps agree across every channel. No empty
fragments, nonzero fragment status bits, or incomplete events. Every frame
passes version 4 / 512-byte / 256-sample / software tag 3 / continuation-off
checks, with every ADC value checked as 14-bit. See hdf5-summary.json.

Software and combined modes accepted each of 20 PS forced commands on all
16 connected channels. BNC-only, xcorr-only, timing-only and global inhibit
rejected all 20 software commands. This does not establish acceptance of
physical BNC pulses or real timing commands, which were not supplied.

The original build overlay failed because its SDT fragment referenced the
OS-missing imux symbol and a different binary filename. The deployed DTBO is
the proven 662c3fe board overlay with a same-length firmware filename change;
BD differences introduce no AXI-map or OS device-node changes. The bitstream
binary is unmodified 14f56c3. overlay-repair.json records both overlay hashes.
Use the separate board-compatible package, not the original build ZIP, on
this board OS. The original overlay and rollback images are preserved.

Earlier run 45323 also has all 16 channels, but its bounded producer ended
before the last DAQ requests, producing 226 empty fragments per source. The
controlled run 45324 kept software production active throughout DAQ stop and
is the qualification file. DAQ is stopped after testing; the new image remains
loaded with software-only selection and continuation disabled.

Remote evidence: /nfs/home/marroyav/workareas/daq/daphne/deploy-14f56c3-20260930
Original file on np04-srv-003:
/data1/np02vd_raw_run045324_0000_df-s03-d1_dw_0_20260930T163207.hdf5
Cooper build: /tmp/arroyave/work/trigger-selector-bit-14f56c3-20260930
Local evidence: /home/arroyave/work/daphne-256-deploy-14f56c3-20260930

Shutdown limitation: after successful stop-run and closed-file validation, the
readout process runp02srv001eth1 terminated with exit code 134 during shutdown.
Other child processes exited 0. No DAQ children remain running. This requires
a fresh boot for the next run and is not evidence of waveform corruption;
the shutdown failure itself has not been diagnosed in this qualification.
The board runtime, server and Hermes services remain active on 14f56c3.
