# Composable formal CI repair

The branch's GitHub Formal workflow failed from its first grouped32 commit
through `4d068b0`. The `default`, `cover-fast`, and `boundary-cover` matrices
passed; `composable` and `composable-cover` failed. Reproducing `4d068b0`
locally with the CI-pinned OSS CAD Suite `2026-04-08` showed that the four
composable proofs stopped at VHDL import: the formal harness instantiations
omitted the required `force_calibration_tag_i` port. The production RTL already
connected that port.

Commit `a6728f2` adds a symbolic two-bit calibration-tag input to the four
composable harnesses and connects it to all seven matching shell/core/top
instances. Shared comparisons receive the same symbolic value; the proof is
not restricted to a fixed calibration tag. No formal assertion or production
RTL was removed or relaxed.

The exact CI tool archive was
`oss-cad-suite-linux-x64-20260408.tgz`, SHA-256
`c311f21d47ee858625fcbc50b932abc1a5b0020b79745031867908b125a71c02`.
The local repair worktree passed all five workflow suites:

| Suite | Passed | Failed |
| --- | ---: | ---: |
| default | 4 | 0 |
| cover-fast | 2 | 0 |
| boundary-cover | 3 | 0 |
| composable | 4 | 0 |
| composable-cover | 4 | 0 |

Reproduce with `OSS_CAD_SUITE_ENV` pointing to the extracted release's
`environment` file and run
`./scripts/formal/run_formal.sh --suite <suite>` for each row. The
[GitHub Formal run for `a6728f2`](https://github.com/DUNE-DAQ/daphne-firmware/actions/runs/34900350376)
completed successfully across all five required matrices. This addresses the
CI import failure; it does not substitute for routed K26C timing or the other
firmware qualification gates.
