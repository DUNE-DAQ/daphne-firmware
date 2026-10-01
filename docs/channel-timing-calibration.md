# Channel timing calibration

The grouped32 path supports a runtime calibration mask while the board selector
remains in xcorr mode (`0x88000034 = 2`). This requires new gateware; the deployed
`14f56c3` image does not implement these registers. No board was flashed for this
change. Timing lock, command delivery and matching command configuration must
already work.

For each set bit, that channel accepts only the matching timing command. Xcorr,
software and BNC triggers are rejected and waveform continuation is disabled.
Other channels retain the board trigger policy and their continuation settings.
Clearing a bit restores that channel's existing settings. Channel enable bits and
global inhibit still apply. The mask does not enable a disabled channel.
The command selector (`0x88000028`) remains shared across the board.

| Address | Access | Meaning |
| --- | --- | --- |
| `0xA0010F00` | R/W | Complete calibration mask; bit N selects channel N, 0..31 |
| `0xA0010F04` | R/O | Applied mask after changed-channel pipeline holdoff |
| `0xA0010F08` | R/O | Capability signature `0x43414C32` (`CAL2`) |
| `0xA0010F0C` | R/W | Pause admission mask; selected filters keep running |
| `0xA0010F10` | R/O | Applied pause mask after the pipeline holdoff |
| `0xA0010F14` | R/O | Paused channels with all local reserved packet slots drained |

Mask indices are firmware/PL channel IDs, matching record headers. The server's
physical channel numbering uses `AFE_board2PL_map`; translate that numbering
before constructing masks. This grouped32 build reads PL AFEs 0..3; PL AFE 4
is outside this acquisition path.

Use full 32-bit writes. Partial writes are ignored. Reset clears the mask.
Only changed channels pause admission for 64 sample clocks; filter state,
sample history, counters and queued packets are preserved. Both mask crossings
use coherent handshakes. Serialise updates under one controller and wait for the
applied mask to equal the desired mask before sending calibration commands.

On a board running this gateware, with Python 3 and `devmem`:

```sh
sudo python3 scripts/control/set_calibration_channels.py --channels 0 7 31
# Send matching timing commands and collect calibration data.
sudo python3 scripts/control/set_calibration_channels.py --restore
```

`--channels` replaces the complete selection, rather than adding channels.
The helper checks capability and xcorr mode before writing; it changes neither
the board selector nor channel enable bits.

An applied-mask acknowledgement establishes source selection, not a data-drain
boundary. Previously queued records may arrive later. Calibration records carry
the existing timing calibration tag (`1`); retain channel selection, settings,
timing command timestamps and step identifiers in scan metadata, and select
records by channel, tag and timestamp. Keep the DAQ configured during the scan.
Record step boundaries after settings readback and settling, before issuing the
step's timing commands. Return channels only after the last command's capture
window has completed. Host-side scan orchestration remains separate.

Local verification:

```sh
python3 scripts/verification/run_channel_calibration_tests.py
python3 scripts/verification/run_continuation_tests.py
python3 scripts/verification/run_board_readout_elaboration.py
```

The calibration test exercises the production eight-channel island, real timing
match/pipeline, frame sources and serializers. A filter fixture injects xcorr
candidates; it does not qualify analog filtering. Counter/continuation regression
and board interface elaboration use behavioural XPM models. Routing/timing
closure and physical timing-command delivery still require a hardware build and
board qualification.

## Scan transactions

Use the hardware scope of each variable to choose the affected set:

| Variable | Server control scope |
| --- | --- |
| AFE bias, attenuation | Whole AFE, eight channels |
| Trim, offset | Individual channel |
| Global bias enable/control | Whole board |

An AFE transaction should pause new captures for every electrically affected
channel, drain pending data, write settings, check available readback and wait
for analog settling, apply the timing calibration selection, resume selected
channels, and issue timing commands. Record only after the step boundary.
For an AFE bias scan, a smaller acquisition subset does not protect the other
channels in that AFE from the bias change. Per-channel bias adjustment uses trim.
Shared DAC/SPI access must be serialised by the board controller even when
transactions belong to different AFEs. Settings returned from the server's
cached state are not independent measurements of the actual analog value.

The existing channel enable mask can stop new capture admission; packets already
queued still drain. The pause mask stops admission without disabling filters. Poll the applied
pause mask, then the drained bits for the affected set before changing settings.
The drain acknowledgement includes queued capture windows, descriptors,
serialization and packet-store output. It does not include Hermes or downstream
DAQ buffers. Timing tags and timestamps identify delayed network arrivals.
The controller must serialise settings, settling, metadata and mask restoration. Do not shut down the DAQ per step.
