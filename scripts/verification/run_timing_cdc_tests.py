#!/usr/bin/env python3
"""Check timing-endpoint CDC state progression with unrelated source clocks."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GHDL = os.environ.get('GHDL') or shutil.which('ghdl')
if not GHDL:
    raise SystemExit('GHDL is required')

sources = [ROOT / 'ip_repo/daphne_ip/rtl/timing' / name for name in (
    'pdts_defs.vhd', 'pdts_clock_defs.vhd', 'pdts_synchro.vhd',
    'pdts_synchro_pulse.vhd', 'pdts_ep_sm.vhd')]
sources.append(ROOT / 'tests/logic/pdts_completion_cdc_tb.vhd')
with tempfile.TemporaryDirectory(prefix='daphne-timing-cdc-') as directory:
    # The imported PDTS synchronizer places a port attribute in its architecture;
    # relaxed analysis accepts that Vivado-supported construct with a warning.
    flags = ['--std=08', '-frelaxed-rules']
    subprocess.run([GHDL, '-a', *flags, *map(str, sources)], cwd=directory, check=True)
    result = subprocess.run([GHDL, '--elab-run', *flags, 'pdts_completion_cdc_tb',
                             '--assert-level=error', '--ieee-asserts=disable-at-0'],
                            cwd=directory, check=True, text=True, stdout=subprocess.PIPE)
    print(result.stdout, end='')
    if 'pdts_completion_cdc_tb PASS' not in result.stdout:
        raise SystemExit('Simulation ended without PASS')
