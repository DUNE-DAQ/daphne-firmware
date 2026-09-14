#!/usr/bin/env python3
"""Local fixed512 grouped-builder verification; never launches Vivado synthesis."""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import os
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[2]
GHDL=os.environ.get('GHDL') or shutil.which('ghdl') or str(Path.home()/'tools/oss-cad-suite/bin/ghdl')
SOURCES=[
    "rtl/isolated/common/primitives/stream_reset_sync.vhd",
    "tests/logic/stream_reset_sync_tb.vhd",
    'ip_repo/daphne_ip/rtl/daphne_package.vhd',
    'rtl/isolated/common/daphne_subsystem_pkg.vhd',
    'rtl/isolated/subsystems/trigger/grouped_frame_pkg.vhd',
    'rtl/isolated/common/primitives/grouped_sample_ring.vhd',
    'rtl/isolated/common/primitives/sample_ring_buffer_single.vhd',
    'rtl/isolated/common/primitives/packet_frame_store.vhd',
    'rtl/isolated/subsystems/trigger/fragment_peak_descriptors_banked.vhd',
    'rtl/isolated/subsystems/trigger/stc3_frame_source.vhd',
    'rtl/isolated/subsystems/trigger/stc3_record_builder.vhd',
    'rtl/isolated/subsystems/trigger/afe_stc3_stream_serializer.vhd',
    'rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd',
    'tests/logic/stc3_grouped_test_adapter.vhd',
    'tests/logic/grouped32_replay_tb.vhd',
]
def descriptor_oracle(samples, baseline, positive):
    amplitudes = [max(0, sample - baseline if positive else baseline - sample) for sample in samples]
    runs = []
    start = None
    for index, amplitude in enumerate(amplitudes + [0]):
        if amplitude > 64 and start is None:
            start = index
        elif amplitude <= 64 and start is not None:
            values = amplitudes[start:index]
            runs.append((start, sum(values), max(values), values.index(max(values)), len(values)))
            start = None
    trailer = [0x7fffffff if index < 10 and index % 2 == 0 else 0xffffffff for index in range(12)]
    for slot, (start, integral, peak, argmax, duration) in enumerate(runs[:5]):
        trailer[2 * slot] = 0x80000000 | (integral << 8) | 0xf1
        trailer[2 * slot + 1] = (min(duration, 511) << 23) | (argmax << 14) | peak
        word, shift = ((10, 22), (10, 12), (10, 2), (11, 22), (11, 12))[slot]
        trailer[word] = (trailer[word] & ~(0x3ff << shift)) | (start << shift)
    return trailer, int(len(runs) > 5)


def check_packets(path, mode):
    records=[{},{}]
    samples_checked=0
    for implementation,ch,finished,hexdata in csv.reader(path.open()):
        implementation,ch,finished=map(int,(implementation,ch,finished))
        assert len(hexdata)==1920, 'wrong record size'
        data=int(hexdata,16)
        timestamp=data&((1<<64)-1)
        header=(data>>64)&((1<<64)-1)
        assert header>>56==ch
        assert (header>>52)&15==3
        assert (header>>46)&3==ch%4
        assert (header>>50)&1==1
        payload=data>>512
        samples=[]
        for i in range(512):
            n=timestamp+i
            onset=256+(ch*7 if mode==1 else 0)
            amp=200+(n*13+ch*17)%1500 if onset<=n<54000 and (ch%3!=0 or n%40<32) else 0
            expected=8000-amp if ch%2==0 else 4000+amp
            actual=(payload>>(14*i))&16383
            samples.append(actual)
            assert actual==expected, f'waveform mismatch mode={mode} implementation={implementation} ch={ch} ts={timestamp} sample={i}: {actual} != {expected}'
        trailer, overflow = descriptor_oracle(samples, 8000 if ch%2==0 else 4000, ch%2==1)
        actual_trailer = [(data >> (128 + 32*i)) & 0xffffffff for i in range(12)]
        assert actual_trailer == trailer and (header >> 49)&1 == overflow, f'independent descriptor mismatch ch={ch} ts={timestamp}'
        assert (header >> 32)&0x3fff == (8000 if ch%2==0 else 12384), 'baseline metadata changed'
        assert (header >> 16)&0x3fff == 0x2345, 'threshold metadata changed'
        if mode == 3:
            assert (header >> 51)&1 == 0, 'continuation unexpectedly enabled in legacy-overlap mode'
        key=(ch,timestamp)
        assert key not in records[implementation], f'duplicate fragment {key}'
        records[implementation][key]=(data,finished)
        samples_checked+=512
    common=records[0].keys()&records[1].keys()
    # Overload changes which candidates are admitted. Require a common
    # reference for every channel, and independently validate ALL records above.
    assert {ch for ch, _ in common} == set(range(32)), 'missing per-channel reference coverage'
    for key in common:
        assert records[0][key][0]==records[1][key][0], f'header/descriptor mismatch {key}'
    if mode in (0,1):
        assert records[0].keys()==records[1].keys(), 'sustainable capture lost fragments'
        for ch in range(32):
            starts=sorted(t for c,t in records[0] if c==ch)
            assert len(starts)>100 and all(b-a==512 for a,b in zip(starts,starts[1:])), 'broken continuation chain'
    return dict(mode=mode,grouped_packets=len(records[0]),reference_packets=len(records[1]),
            byte_identical_common_packets=len(common),samples_checked=samples_checked,
        independent_descriptor_words_checked=12*(len(records[0])+len(records[1])),
            grouped_only=len(records[0].keys()-records[1].keys()),reference_only=len(records[1].keys()-records[0].keys()),
            max_grouped_packet_latency_adc_ticks=max(finished-key[1] for key,(_,finished) in records[0].items()),
            csv_sha256=hashlib.sha256(path.read_bytes()).hexdigest())

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode',type=int,choices=range(5),action='append')
    parser.add_argument('--phase-ps',type=int,default=0)
    parser.add_argument('--skip-existing',action='store_true')
    parser.add_argument('--contracts-only',action='store_true')
    parser.add_argument('--output-dir',type=Path)
    args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='daphne-grouped32-') as td:
        def run(*args):
            result = subprocess.run([GHDL, *map(str, args)], cwd=td, check=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            print(result.stdout, end='', flush=True)
            if args[0] == '-r' and ' PASS' not in result.stdout:
                raise AssertionError('Simulation ended without its PASS marker')
        models=ROOT/'tests/logic/models'
        run('-a','--std=08','--work=xpm',*[models/x for x in ['xpm_vcomponents.vhd','xpm_memory_sdpram.vhd','xpm_cdc_handshake.vhd','xpm_fifo_async.vhd']])
        run('-a','--std=08',*[ROOT/x for x in SOURCES])
        run('-e', '--std=08', 'stream_reset_sync_tb')
        for stages in (2,4,8):
            run('-r', '--std=08', 'stream_reset_sync_tb', f'-gSTAGES_G={stages}', '--assert-level=error', '--stop-time=1us')
        for bench in ([] if args.skip_existing else ['stc3_continuation_tb','stc3_continuation_edges_tb','stc3_continuation_overload_tb']):
            src=(ROOT/'tests/logic'/f'{bench}.vhd').read_text().replace('entity work.stc3_record_builder','entity work.stc3_grouped_test_adapter')
            path=Path(td)/f'{bench}.vhd'; path.write_text(src)
            run('-a','--std=08',path); run('-e','--std=08',bench)
            for opts in ([['-gODD_START_G=0'],['-gODD_START_G=1']] if bench=='stc3_continuation_tb' else [[]]):
                run('-r','--std=08',bench,*opts,'--assert-level=error','--ieee-asserts=disable-at-0','--stop-time=2ms')
        if args.contracts_only:
            print('Grouped builder reset and existing contracts PASS')
            return
        output_dir=(args.output_dir or Path(td)).resolve()
        output_dir.mkdir(parents=True,exist_ok=True)
        run('-e','--std=08','grouped32_replay_tb')
        results=[]
        for mode in (args.mode if args.mode is not None else range(5)):
            path=output_dir/f'mode{mode}-phase{args.phase_ps}.csv'
            run('-r','--std=08','grouped32_replay_tb',f'-gMODE_G={mode}',f'-gPHASE_PS_G={args.phase_ps}',
                            f'-gOUTPUT_G={path}','--assert-level=error','--ieee-asserts=disable-at-0','--stop-time=2ms')
            result=check_packets(path,mode); result['phase_ps']=args.phase_ps; results.append(result)
            print(json.dumps(result),flush=True)
        (output_dir/f'summary-phase{args.phase_ps}.json').write_text(json.dumps(results,indent=2)+'\n')
    print('Grouped builder local RTL regressions PASS')
if __name__=='__main__': main()
