# Grouped256 cleanup inventory — 2026-09-16

## Scope and evidence

This is a read-only inventory; nothing was removed.  The required bounded
workspace audit was run before this review.  Its machine-readable and Markdown
outputs are at:

- `/home/neutrino/work/workflow/reports/grouped256-cleanup-20260916/workspace-audit.json`
- `/home/neutrino/work/workflow/reports/grouped256-cleanup-20260916/workspace-audit.md`

The audit reported 28 dirty worktrees, including the active production tree.
Its result is a preservation signal, not deletion authorization.  Local and
Cooper allocation figures below are `du -sh` (allocated blocks, not apparent
file size).  Inventories were shallow: generated build roots, immediate
children, and relevant artifact/status file types only; archives were not
recursively searched.

At the time checked, the local process list had no Vivado/Vitis/FuseSoC/XSim
job (only the inventory command itself).  Cooper had no build job either; its
only matching processes were the long-running Vivado `hw_server` service
(PIDs 3199381/3199425/3199471, started 2026-08-18).  That service is not
evidence that an individual scratch run is active, but it must not be stopped
as part of cleanup.

## Explicit exclusions

Do not remove these paths in a generated-build cleanup.

| Path | Reason |
| --- | --- |
| `/home/neutrino/work/daphne/firmware/worktrees/daphne-firmware-256-5-production` | Active production 256/5 tree; dirty in the required audit. |
| `/home/neutrino/work/daphne/firmware/worktrees/daphne-firmware-512-32ch-grouped4/build` (59 MiB) | Grouped32 baseline: five mode/phase replay CSVs (8.5–13.8 MB each) and their summaries. |
| `/home/neutrino/work/daphne/firmware/worktrees/daphne-selftrigger-dual-abi-v2` and all other dirty worktrees | Required audit says preserve; generated-looking output is not enough reason to touch a dirty tree. |
| `/home/neutrino/work/daphne/firmware/repos/daphne-firmware` and `/home/neutrino/work/daphne/firmware/worktrees/daphne-firmware-rpu` | Dirty and contain ongoing/manual-build or staged deployment evidence; the RPU tree includes a staged `.dtbo`. |
| `/tmp/arroyave/work/current` root, deployment kits, evidence, and symlinked children | Retain as a container and release/evidence area; the later `current` section names three audited `build/tmp` exceptions only. |
| `/tmp/arroyave/work/dsc512-base-20260911T133500Z` (768 MiB), `/tmp/arroyave/work/dsc512-four-9d02e99-20260911` (1001 MiB), and all `ooc-512-*` report roots | Baseline/production or architecture-evidence material. `dsc512-four-9d02e99` has exit code 0 and artifact status saying artifacts were produced. OOC roots contain unique timing, clock, utilization, and synthesized-DCP report sets. |

No `.bit`, `.bin`, `.xsa`, or `.dtbo` file was found under any *recommended*
generated-build candidate below in the shallow artifact scan.  This is not a
claim about the excluded releases, deployment kits, archives, or deeper trees.

## Local candidates: generated FuseSoC build copies

These three clean, dated worktrees have no matching active process and their
listed build directories contain generated FuseSoC source copies only in the
shallow scan—no bitstream, XSA, DTBO, DCP, or report file was found.  Remove
only the exact `build` directory, not its parent worktree.

| Recommended explicit path | Allocated size | Evidence / rationale |
| --- | ---: | --- |
| `/home/neutrino/work/daphne/firmware/worktrees/daphne-fullstream-mux-a002/build` | 13 MiB | Clean worktree; generated `impl-vivado` and `fusesoc-logic` trees. |
| `/home/neutrino/work/daphne/firmware/worktrees/daphne-firmware-512-continuation/build` | 27 MiB | Clean worktree; generated `fusesoc-logic` copies only. |
| `/home/neutrino/work/daphne/firmware/worktrees/daphne-firmware-os-split/build` | 36 MiB | Clean worktree; generated `fusesoc-logic` copies only. |

Expected reclaim: about **76 MiB allocated**.  The similarly shaped clean
`daphne-develop/build` (36 MiB) is deliberately a **hold**, since its name does
not establish that it is obsolete.  The small build directories in dirty
`daphne-firmware-db`, `daphne-firmware-grouped-hermes-arch-draft-ddffe68`, and
`daphne-firmware-rpu` are also holds.  Four-kilobyte `.fusesoc`/`.cache/fusesoc`
metadata directories are not worth a separate cleanup operation.

## Cooper candidates: disposable simulator intermediates only

The following exact paths are generated XPM/XSim intermediates below failed or
superseded 512 experiments.  Preserve their parent run directories and the
`evidence`, `hierarchy-audit`, `synth-resources`, and `*.rpt`/`*.dcp` content.
The `dsc512-cont-0403d97` and `dsc512-four-a4e91e8` parents retain hierarchy
utilization reports; `dsc512-cont-355376f` retains compensator and synthesis
resource reports.  Their recorded exits were respectively 130, 1/127, and 1.

| Recommended explicit path | Allocated size |
| --- | ---: |
| `/tmp/arroyave/work/dsc512-cont-0403d97-20260911/vendor-memory-sim/xpm` | 1.2 MiB |
| `/tmp/arroyave/work/dsc512-cont-0403d97-20260911/vendor-memory-sim/xsim.dir` | 2.0 MiB |
| `/tmp/arroyave/work/dsc512-cont-355376f-20260911/vendor-memory-sim-attempt02/xpm` | 1.2 MiB |
| `/tmp/arroyave/work/dsc512-cont-355376f-20260911/vendor-memory-sim-attempt02/xsim.dir` | 2.0 MiB |
| `/tmp/arroyave/work/dsc512-cont-a1444c7-20260911/vendor-memory-sim/xpm` | 1.2 MiB |
| `/tmp/arroyave/work/dsc512-cont-a1444c7-20260911/vendor-memory-sim/xsim.dir` | 1.9 MiB |
| `/tmp/arroyave/work/dsc512-cont-afd3b84-20260911/vendor-memory-sim/xpm` | 1.2 MiB |
| `/tmp/arroyave/work/dsc512-cont-afd3b84-20260911/vendor-memory-sim/xsim.dir` | 2.0 MiB |

Expected reclaim: about **12.7 MiB allocated**.  Empty/zero-allocation `.Xil`,
`.fusesoc`, `.cache`, and several historical failed-build directories were
also observed, but are deliberately not listed as action items because they
have no material allocation benefit and can contain provenance markers.

## Cooper `current`: high-reclaim generated build intermediates

`/tmp/arroyave/work/current` resolves to itself: it is a physical directory,
not a top-level symlink (inode `77647429`, last modified 2026-09-09).  It is
127 GiB allocated, mostly two dated Petalinux efforts rather than a live 256
campaign:

| Top-level child | Allocated size |
| --- | ---: |
| `daphne-dual-dev-20260908-cenoop` | 51 GiB |
| `daphne-os-split-20260908-4Jltem` | 72 GiB |
| `daphne-wic-source-check-w8lm20Bs` | 3.5 GiB |
| `deployment-kits` | 1.2 GiB |
| `evidence` | 78 MiB |

The `firmware`, `hardware-database`, `petalinux`, and `session` entries inside
`current` are symlinks to older external run roots.  They are not candidates
and none of their targets should be removed through this inventory.

At inspection time, no process had a CWD under `current`, and `lsof` reported
no open file beneath it.  The existing tmux sessions were historical
fullstream/self-trigger/GIZMO sessions; none reported `current` as a pane
path.  Several stale pane PIDs no longer existed; the one live pane was in the
separate GIZMO source directory.  This is adequate evidence for a later
cleanup pass, but the live-process and tmux checks must be repeated immediately
before it runs.  No `dsc256*` directory was present at `/tmp/arroyave/work`
depth two during this inspection; any that appears is excluded from deletion.

The large reclaim targets below are Petalinux `build/tmp` work and cache trees,
not packaged outputs.  Their sibling output/input/developer-kit directories
retain `SHA256SUMS`, `.bit`, `.bin`, `.xsa`, `.dtbo`, boot images, and release
archives.  The output artifacts are therefore intentionally outside the
candidate paths.  No large `.runs`, `ip_user_files`, `.Xil`, or XPM directory
was found in `current`; the `.Xil` directories found there are at most 48 KiB.

| Recommended explicit path | Allocated size | Retained assets |
| --- | ---: | --- |
| `/tmp/arroyave/work/current/daphne-dual-dev-20260908-cenoop/petalinux-dev/build/tmp` | 14 GiB | `petalinux-output`, two timestamped prior output sets, developer kit, source, and gateware inputs remain. |
| `/tmp/arroyave/work/current/daphne-os-split-20260908-4Jltem/petalinux-developer/build/tmp` | 14 GiB | `output-developer`, inputs, regenerated overlays, developer kit, and validation log remain. |
| `/tmp/arroyave/work/current/daphne-os-split-20260908-4Jltem/petalinux-minimal/build/tmp` | 11 GiB | `output-minimal`, inputs, regenerated overlays, and developer kit remain. |

Expected reclaim: about **39 GiB allocated**.  These directories contain
generated Yocto/Petalinux cache and work state (`tmp/cache` is 1.7–1.8 GiB and
`tmp/work` is 3.2–3.6 GiB); an intentional rebuild can recreate them.  Do not
remove the surrounding `build` directory in this pass: its downloads,
sstate, configuration, and any target-specific provenance need separate
deduplication/retention review.

The 5.2 GiB `developer-workspace-5n5yyc` and 7.3 GiB
`developer-workspace-SbRHat` directories are **holds**, not candidates.  Both
contain an identically hashed `original.wic`, but their `rootfs.ext4` hashes
differ, and only the latter has `WIC-VALIDATION.json`; there is not yet a
preservation manifest proving the first workspace disposable.  Likewise,
native-validation root files contain duplicate gateware binaries (the sampled
fullstream and self-trigger `.bin` files match the preserved
`output-developer` hashes), but their logs and complete manifests have not been
reconciled, so they remain holds.

## Executed cleanup — 2026-09-16

The user authorized removal of the three local and eight Cooper intermediate
paths listed below.  Immediately before deletion, each local parent worktree
was clean; no local Vivado/Vitis/FuseSoC/XSim job was running; all targets
resolved to their literal listed path; and recursive scans found no `.bit`,
`.bin`, `.xsa`, `.dtbo`, `.dcp`, `*.rpt`, checksums, build-status files, or
JSON provenance files.  The local directories contained generated FuseSoC
source copies only.

Cooper preflight found the active `dsc256-7d0ea761-20260916` vendor simulation
(`xelab` and its `daphne-256-7d0ea761` tmux session); it was not a cleanup
target and remains intact.  No process CWD was within the eight selected older
512 intermediate directories.  Their recursive scans found no release or
report/provenance asset.  The `xsim.dir` Tcl scripts and XPM libraries were
generated simulator state, so no archive was required.

| Removed exact path | Pre-removal allocated size |
| --- | ---: |
| `/home/neutrino/work/daphne/firmware/worktrees/daphne-fullstream-mux-a002/build` | 13 MiB |
| `/home/neutrino/work/daphne/firmware/worktrees/daphne-firmware-512-continuation/build` | 27 MiB |
| `/home/neutrino/work/daphne/firmware/worktrees/daphne-firmware-os-split/build` | 36 MiB |
| `/tmp/arroyave/work/dsc512-cont-0403d97-20260911/vendor-memory-sim/xpm` | 1.2 MiB |
| `/tmp/arroyave/work/dsc512-cont-0403d97-20260911/vendor-memory-sim/xsim.dir` | 2.0 MiB |
| `/tmp/arroyave/work/dsc512-cont-355376f-20260911/vendor-memory-sim-attempt02/xpm` | 1.2 MiB |
| `/tmp/arroyave/work/dsc512-cont-355376f-20260911/vendor-memory-sim-attempt02/xsim.dir` | 2.0 MiB |
| `/tmp/arroyave/work/dsc512-cont-a1444c7-20260911/vendor-memory-sim/xpm` | 1.2 MiB |
| `/tmp/arroyave/work/dsc512-cont-a1444c7-20260911/vendor-memory-sim/xsim.dir` | 1.9 MiB |
| `/tmp/arroyave/work/dsc512-cont-afd3b84-20260911/vendor-memory-sim/xpm` | 1.2 MiB |
| `/tmp/arroyave/work/dsc512-cont-afd3b84-20260911/vendor-memory-sim/xsim.dir` | 2.0 MiB |

All eleven paths were confirmed absent after deletion.  The reclaim was about
**76 MiB local plus 12.7 MiB Cooper allocated**.  Deletion is not a retained
backup: the generated content is recoverable only by rerunning the documented
FuseSoC/Vivado/XSim flows from the preserved source and parent run metadata.

Retained Cooper evidence includes the parent `evidence`, `hierarchy-audit`,
`synth-resources`, and compensator-resource directories; no report set, DCP,
release package, or active/new-256 directory was deleted.

## Preconditions for a later deletion pass

1. Recheck the relevant local/remote process lists and Cooper tmux sessions.
2. Recheck every listed path with `du -sh` and perform a targeted artifact scan
   for `.bit`, `.bin`, `.xsa`, `.dtbo`, `.dcp`, `*.rpt`, and status files.
3. On Cooper, retain the parent evidence/report directories named above; do not
   delete release roots, deployment kits, `dsc256*`, or baseline/prod campaign
   roots.  Within `current`, delete only the exact `build/tmp` paths listed
   above after the repeat active-use check.
4. Record actual removed paths and reclaimed allocation in the cleanup handoff.
