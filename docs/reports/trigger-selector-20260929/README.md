# 256-sample Ethernet trigger selector qualification

Candidate based on 662c3fe, retaining its two-fiber/four-logical-stream compact
v4 frame format. The frontend selector now controls Ethernet software, BNC,
xcorr and timing-command admission. See the
[register and source contract](../../../formal/contracts/readout-trigger-policy.md).

Local checks passed on 2026-09-29:

* All 33 checked-in formal proof/cover jobs via `run_formal.sh --suite all-local`.
  The installed OSS CAD Suite is 2026-04-08, matching `.github/workflows/formal.yml`.
  Per-job results are saved in `formal-status.json`. New jobs are included in
  default/leaf-fast and cover-fast suites, and cover traces are included in CI
  artifact collection. The frontend AXI proof covers the extended fourth bit.
* `run_grouped32_tests.py --contracts-only`: all 128 mode/source combinations,
  inhibit, timing, invalid modes, source tags and baseline retention; active-chain
  source change and inhibit stop continuation while queued frames drain; a
  subsequent BNC event starts a fresh chain. Existing continuation alignment,
  late tuples, quiet termination and overload/recovery contracts also pass.
* `run_board_readout_elaboration.py`: transport, selftrigger plane, board shell
  and public top pass using real interface declarations and boundary stubs.
* `fe_axi_smoke_tb`: extended timing selector full-write/readback and partial
  write rejection, plus existing frontend register and trigger tests.
* Register-map consistency, board-shell dependency contract, frontend and
  selftrigger plane contracts, AFE timing/CDC constraint contract, and
  `git diff --check` pass.

The source manifests were regenerated, adding the selector and including two
already tracked timing CDC units missing from the previous checked-in manifests.
No Hermes packet format, physical link count, timing endpoint algorithm, or
continuation threshold ABI changes are part of this candidate. Bit 3 extends
Ethernet selection while existing selector/inhibit bits and the spy path's
legacy mapping remain in place. No timing commands are disabled globally.

Proof scope is the control policy and frontend AXI leaf contracts. Simulation
uses behavioral XPM models and modeled timing-strobe rejection; it is not an
end-to-end proof of the timing endpoint, signal-processing or Ethernet path.
Vendor synthesis, timing closure and on-board acquisition qualification remain
separate. The source is committed on `marroyav/256_frame`; the build must use a
fresh Cooper clone from the exact committed bundle. No board programming is
performed as part of this synthesis submission.
