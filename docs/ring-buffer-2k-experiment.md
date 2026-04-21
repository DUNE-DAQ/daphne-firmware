# Ring Buffer 2k Experiment

This branch is the 2k BRAM ring-buffer experiment on top of the
instrumented 1k ring branch.

Current contract:
- frame length: 512 samples
- pretrigger: 64 samples
- ring depth: 2048 samples
- overlap: configurable through `signal_delay_i` in 16-sample steps

Behavioral note:
- waveform capture is the primary contract
- peak-descriptor trailers are only fully trustworthy when overlap is zero
- overlapping frames are allowed for experimentation, but the descriptor/trailer ownership policy is not yet redesigned for that case

Scope:
- builder waveform storage moves to explicit XPM BRAM-backed ring buffers
- no BRAM delay-bank migration is included in this branch
- builder instrumentation now splits rejected events into:
  `spacing`, `queue`, `ring`, and `output-full` counters at the
  `stc3_record_builder` boundary
- queue depth remains `4`; this branch changes only ring retention depth
  so the dead-time probe can isolate the effect of a deeper sample store

WSL/Windows note:
- host workflow directive for this branch:
  - build on a Windows machine
  - manage `git` from WSL
  - run Vivado from Windows PowerShell, not through WSL wrappers
  - current observed behavior is that native PowerShell Vivado execution is
    about `6x` faster than the WSL-driven path
- if a run was launched with `DAPHNE_STOP_AFTER_SYNTH=1`, resume the same
  output directory with:
  `./scripts/wsl/resume_impl_from_synth.sh`
- the script reuses `xilinx/output-<gitsha>/<bd_name>_synth.dcp` and continues
  with opt/place/route/bit/xsa generation instead of rerunning synthesis
