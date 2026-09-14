#!/usr/bin/env python3
"""Exercise grouped builders with the installed AMD XPM memory/CDC/FIFO models."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

from run_grouped32_tests import ROOT, SOURCES, check_packets


def host_link_environment(host_gcc):
    """Let bundled GCC find the host's multiarch C runtime startup objects."""
    compiler = shutil.which(host_gcc)
    if compiler is None:
        raise RuntimeError('Host C compiler not found: ' + host_gcc)
    startup_files = []
    for name in ('crt1.o', 'crti.o', 'crtn.o'):
        filename = subprocess.check_output(
            [compiler, '-print-file-name=' + name], text=True).strip()
        path = Path(filename)
        if not path.is_file():
            raise RuntimeError('Host C runtime development file not found: ' + name)
        startup_files.append(path.resolve())
    directories = list(dict.fromkeys(str(path.parent) for path in startup_files))
    env = os.environ.copy()
    if env.get('LIBRARY_PATH'):
        directories.append(env['LIBRARY_PATH'])
    env['LIBRARY_PATH'] = os.pathsep.join(directories)
    return env, {
        'host_gcc': compiler,
        'host_gcc_version': subprocess.check_output([compiler, '--version'], text=True),
        'LIBRARY_PATH': env['LIBRARY_PATH'],
        'startup_sha256': {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in startup_files},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True,
                        help='new directory; existing output is never reused')
    parser.add_argument('--vivado-root', type=Path,
                        default=Path(os.environ.get('XILINX_VIVADO', '/opt/Xilinx/2026.1/Vivado')))
    parser.add_argument('--mode', type=int, choices=range(5), action='append')
    parser.add_argument('--phase-ps', type=int, default=700)
    parser.add_argument('--contracts-only', action='store_true')
    parser.add_argument('--host-gcc', default='gcc',
                        help='host C compiler used to locate runtime startup objects')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    vivado = args.vivado_root.resolve()
    xpm = vivado / 'data/ip/xpm'
    vendor_files = [xpm / name for name in (
        'xpm_VCOMP.vhd', 'xpm_cdc/hdl/xpm_cdc.sv',
        'xpm_memory/hdl/xpm_memory.sv', 'xpm_fifo/hdl/xpm_fifo.sv')]
    glbl = vivado / 'data/verilog/src/glbl.v'
    tool_env, toolchain = host_link_environment(args.host_gcc)
    source_files = [ROOT / name for name in SOURCES]
    source_hashes = {}

    def stage_source(original):
        contents = original.read_bytes()
        staged = output / 'sources' / original.relative_to(ROOT)
        staged.parent.mkdir(parents=True, exist_ok=True)
        staged.write_bytes(contents)
        source_hashes[str(original.relative_to(ROOT))] = hashlib.sha256(contents).hexdigest()
        return staged

    staged_sources = [stage_source(original) for original in source_files]
    for script in ('run_grouped32_vendor_tests.py', 'run_grouped32_tests.py'):
        stage_source(ROOT / 'scripts/verification' / script)
    contract_benches = ('stc3_continuation_tb', 'stc3_continuation_edges_tb',
                        'stc3_continuation_overload_tb')
    staged_contracts = {bench: stage_source(ROOT / 'tests/logic' / (bench + '.vhd'))
                        for bench in contract_benches}
    status = {
        'started_utc': datetime.now(timezone.utc).isoformat(),
        'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'source_status': subprocess.check_output(['git', 'status', '--porcelain=v1'], cwd=ROOT, text=True),
        'vivado_root': str(vivado), 'phase_ps': args.phase_ps,
        'source_sha256': source_hashes,
        'vendor_sha256': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in [*vendor_files, glbl]},
        'toolchain': toolchain, 'commands': [],
        'contracts': [], 'cases': [], 'result': 'running',
    }
    (output / 'xpm').mkdir()
    library = 'xpm=' + str(output / 'xpm')

    def run(tool, *arguments):
        command = [str(vivado / 'bin' / tool), *map(str, arguments)]
        print('Running:', ' '.join(command), flush=True)
        result = subprocess.run(command, cwd=output, env=tool_env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        console_log = '%02d-%s-console.log' % (len(status['commands']) + 1, tool)
        (output / console_log).write_text(result.stdout)
        status['commands'].append({'argv': command, 'returncode': result.returncode,
                                   'console_log': console_log})
        print(result.stdout, end='', flush=True)
        result.check_returncode()
        return result.stdout

    def simulate(bench, snapshot, generics=()):
        generic_args = [arg for value in generics for arg in ('--generic_top', value)]
        run('xelab', '--debug', 'typical', '--relax', '--verbose', '2', '--mt', '4', '-L', library, '-L', 'unisims_ver',
            *generic_args, 'work.' + bench, 'work.glbl', '--snapshot', snapshot,
            '--log', 'elaborate-' + snapshot + '.log')
        log = run('xsim', snapshot, '--runall', '--onerror', 'quit',
                  '--log', 'simulate-' + snapshot + '.log')
        if re.search(r'^(?:ERROR|FATAL|FAILURE):', log, re.IGNORECASE | re.MULTILINE):
            raise RuntimeError(snapshot + ' reported a simulation error')
        if bench + ' PASS' not in log:
            raise RuntimeError(snapshot + ' ended without its PASS marker')
        status['contracts'].append({'bench': bench, 'snapshot': snapshot,
                                    'generics': list(generics), 'result': 'PASS'})

    try:
        run('xvhdl', '--2008', '--work', library, vendor_files[0], '--log', 'compile-xpm-vhdl.log')
        run('xvlog', '--sv', '--work', library, *vendor_files[1:], '--log', 'compile-xpm-verilog.log')
        run('xvlog', '--work', 'work', glbl, '--log', 'compile-glbl.log')
        run('xvhdl', '--2008', '--work', 'work', *staged_sources, '--log', 'compile-design.log')
        for stages in (2, 4, 8):
            simulate('stream_reset_sync_tb', 'stream_reset_stages' + str(stages),
                     ['STAGES_G=' + str(stages)])
        simulate('afe_stc3_stream_serializer_tb', 'serializer_contract')
        for bench in contract_benches:
            adapted = output / (bench + '.vhd')
            adapted.write_text(staged_contracts[bench].read_text().replace(
                'entity work.stc3_record_builder', 'entity work.stc3_grouped_test_adapter'))
            run('xvhdl', '--2008', '--work', 'work', adapted, '--log', 'compile-' + bench + '.log')
            if bench == 'stc3_continuation_tb':
                for odd in (0, 1):
                    simulate(bench, bench + '_odd' + str(odd), ['ODD_START_G=' + str(odd)])
            else:
                simulate(bench, bench)
        if not args.contracts_only:
            for mode in (args.mode if args.mode is not None else range(5)):
                csv_path = output / ('mode' + str(mode) + '.csv')
                simulate('grouped32_replay_tb', 'grouped32_mode' + str(mode),
                         ['MODE_G=' + str(mode), 'PHASE_PS_G=' + str(args.phase_ps),
                          'OUTPUT_G=' + str(csv_path)])
                status['cases'].append(check_packets(csv_path, mode))
        status['result'] = 'PASS'
        print('Grouped32 vendor XPM regressions PASS', flush=True)
    except subprocess.CalledProcessError as error:
        print(error.stdout or '', end='', flush=True)
        status['result'] = 'FAIL'
        status['error'] = str(error)
        raise
    except Exception as error:
        status['result'] = 'FAIL'
        status['error'] = str(error)
        raise
    finally:
        status['finished_utc'] = datetime.now(timezone.utc).isoformat()
        (output / 'summary.json').write_text(json.dumps(status, indent=2) + '\n')


if __name__ == '__main__':
    main()
