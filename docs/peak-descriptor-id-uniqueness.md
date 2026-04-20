# Peak Descriptor ID Uniqueness

## Problem

Downstream systems identify a peak descriptor with the channel-scoped key:

`(geo_id, channel_id, frame_timestamp + sample_start)`

The relevant failure mode is therefore not cross-channel reuse of a frame
timestamp. The bug is a same-channel collision where two descriptors within the
same frame export the same `sample_start`.

## RTL Failure Mechanism

The peak-descriptor calculator stores the in-frame start sample in two stages:

- `Time_Start_reg`: pending start sample for the next descriptor
- `Time_Start_reg2`: committed start sample that is exported in trailer words

The old implementation in
[Peak_Descriptor_Calculation.vhd](../ip_repo/daphne_ip/rtl/selftrig/peak_descriptor_import/Peak_Descriptor_Calculation.vhd)
used this priority:

```vhdl
if Ext_Self_Trigger_Match='1' then
  Time_Start_reg <= Time_Start_aux;
elsif Data_Available_aux='1' then
  Time_Start_reg2 <= Time_Start_reg;
end if;
```

That ordering is incorrect for back-to-back descriptors. In
[Peak_Descriptors.vhd](../ip_repo/daphne_ip/rtl/selftrig/peak_descriptor_import/Peak_Descriptors.vhd),
the `Data` state can immediately transition back to `Detection` when
`Self_Trigger='1'`. As a result, the current descriptor can assert
`Data_Available_aux='1'` in the same clock where the next trigger already
asserts `Ext_Self_Trigger_Match='1'`.

With the old `if/elsif` priority, the new trigger overwrote the cycle and the
current descriptor never committed its pending `Time_Start_reg` into
`Time_Start_reg2`. The exported `sample_start` could therefore stay stale and be
reused by a later descriptor in the same frame.

## Fix

The update order must be:

1. Commit the descriptor emitted now: `Time_Start_reg2 <= Time_Start_reg`
2. Capture any new trigger starting in the same cycle:
   `Time_Start_reg <= Time_Start_aux`

The corrected logic is:

```vhdl
if Data_Available_aux='1' then
  Time_Start_reg2 <= Time_Start_reg;
end if;
if Ext_Self_Trigger_Match='1' then
  Time_Start_reg <= Time_Start_aux;
end if;
```

This preserves the current descriptor and still arms the next one.

## Validation Path

The same logic bug existed in the XC mirror in `daphne_mezz_xc_sim`. After
patching both the RTL and the mirror, the replayed `calib10_clean` case changed
from:

- `1646` descriptors
- `19` duplicate absolute IDs

to:

- `1652` descriptors
- `0` duplicate absolute IDs

The duplicate check reconstructs the per-channel absolute ID as:

`frame_start_index + desc_time_start`

and is implemented in:

- `daphne_mezz_xc_sim/scripts/check_descriptor_id_uniqueness.py`

## Operational Guidance

- The downstream DAQ key should remain channel-scoped:
  `(geo_id, channel_id, frame_timestamp + sample_start)`.
- This RTL fix removes the known same-channel collision mechanism in the
  descriptor generator.
- Any future changes in the peak-descriptor path should be replayed through the
  XC mirror and checked with the uniqueness script before deployment.
