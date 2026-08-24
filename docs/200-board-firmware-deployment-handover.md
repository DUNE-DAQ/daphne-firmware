# Multi-board Firmware Deployment Plan

Status: working campaign plan, updated 2026-08-24. Commands intentionally
operate on one isolated board at a time.

## Goal

Build one safe, repeatable workflow that deploys the same qualified firmware
release to approximately 200 DAPHNE boards while applying and verifying the
correct per-board identity and runtime configuration.

The physical correspondence is established at the enrollment station:

```text
scan physical DAPHNE board number
  + read the installed K26 SOM EEPROM
  -> bind board number to SOM UUID, serial, and factory MAC
  -> allocate/recover the approved per-board assignment
  -> derive a versioned runtime/register plan
  -> deploy one common release plus the per-board configuration
  -> read everything back and retain evidence
```

The outcome is not 200 hand-edited images. It is:

1. one immutable release bundle shared by the campaign;
2. one authoritative database record per physical board;
3. one generated, hashed configuration snapshot per board;
4. one generated register plan per board and release;
5. append-only deployment and QA evidence.

## Non-negotiable identity rules

1. The operator manually establishes the physical pairing by scanning or
   entering the **board asset/number while that board is alone in the
   fixture**.
2. The station reads the SOM UUID, serial, product, and MAC ID 0 from the K26
   EEPROM at I2C address `0x50`. Operators should not transcribe the MAC.
3. Under the currently selected `som_eeprom` policy, the production MAC equals
   that board's checksum-valid factory MAC ID 0.
4. The MAC is not calculated from the board number, and register values are not
   calculated from the bytes of the MAC. The database binding makes the values
   correspond.
5. The DAPHNE carrier has no populated carrier FRU EEPROM. Carrier identity
   therefore comes from the physical label and the authoritative asset list.
6. A common image must not contain a board-specific MAC. Do not set a MAC in
   the compiled device tree, FPGA overlay, systemd `.link` file, application
   defaults, or firmware build.
7. The approved MAC must agree across the database, U-Boot `ethaddr`, the
   working device tree, Linux `eth0`, and the network-admission record.
8. A mismatch, duplicate, unreadable EEPROM, invalid checksum, unexpected
   board, or unknown register profile quarantines the unit. Never guess.

## Important count discrepancy

The requested campaign size is 200 boards. Existing notes refer to an
authoritative list of 192 carriers. The next session must resolve this before
creating campaign records:

- obtain the controlled physical asset list;
- record whether the target is 192 production boards plus 8 spares, or 200
  production boards plus additional spares;
- import only real identifiers from that list;
- never synthesize the missing board numbers.

The authoritative CSV template is
[`specs/production/daphne-assets-template.csv`](https://github.com/marroyav/hardware-database/blob/marroyav/daphne-production-qa/specs/production/daphne-assets-template.csv)
on the companion database handover branch. Replace its example row only with
controlled asset data.

## Configuration ownership

Keep immutable release data, per-board assignments, and observed evidence
separate.

| Data | Authority | Examples |
|---|---|---|
| Physical carrier identity | Controlled asset list and scanned label | asset ID, board number, carrier serial/revision |
| Replaceable SOM identity | K26 EEPROM evidence plus production database | UUID, serial, product, factory MAC ID 0, EEPROM SHA-256 |
| Network assignment | Production database and network authority | production MAC, IPv4, hostname, VLAN, authorization |
| Board/runtime assignment | Production database | timing endpoint, firmware release, runtime-profile ID |
| Register definitions and safe values | Qualified release profile | address, mask, allowed range, order, expected readback |
| Installed/observed state | Station evidence | artifact hashes, boot slot, active MAC, readback values, test results |

The board number selects an assignment record. Approved rules may derive a
hostname, IP, or timing endpoint from that board number, but the rule must be
versioned and collision-checked. No operator should perform arithmetic at the
bench.

## Required per-board record

The canonical record must contain at least:

```yaml
asset:
  asset_id: NP04-DAPHNE-NNN
  board_number: NNN
  carrier_serial: controlled-value
  carrier_revision: DAPHNE-V2

som:
  uuid: read-from-eeprom
  serial: read-from-eeprom
  product: SM-K26-XCL2GC-ED
  factory_mac_id_0: read-from-eeprom
  eeprom_sha256: hash-of-raw-8192-byte-dump
  fru_checksum_valid: true

network:
  mac_source: som_eeprom
  production_mac: same-as-factory-mac-id-0
  ipv4_address: approved-value
  hostname: approved-value
  vlan: approved-value
  authorized: false

runtime:
  firmware_release: immutable-release-id
  runtime_profile: released-profile-id
  timing_endpoint: allocated-value
  register_plan_sha256: generated-plan-hash

source:
  assignment_revision: database-revision
  asset_record_revision: database-revision
```

The production database already models most of this. `runtime_profile` and the
register-plan reference are the important missing contract fields.

## Register derivation boundary

The existing `daphne.board-config` version 1 contract contains:

- carrier asset and revision;
- SOM identity and factory MAC;
- production MAC, IP, hostname, VLAN, and authorization;
- timing endpoint;
- firmware release;
- database revisions.

It does **not** yet describe all runtime/register inputs. The current runtime
also consumes or assumes values such as:

- `TIMING_PROFILE`;
- `ENDPOINT_ADDR_HEX`;
- `ENDPOINT_WAIT_MS`;
- `ENDPOINT_SUCCESS_STATES`;
- `ENDPOINT_CLOCK_SOURCE`;
- clock-chip profile, bus, address, verification, and reset policy;
- any Hermes/DAQ identifiers or destinations that vary per board;
- any frontend calibration or operating profile intended for production.

Do not add a free-form list of arbitrary `devmem` writes to the database.
Instead:

1. Add a versioned `runtime_profile` reference to a new board-config contract
   version, or define a separate versioned `daphne.runtime-config` contract.
2. Keep the register map and safe profile definitions with the qualified
   firmware release.
3. Generate a canonical register plan from:

   ```text
   board assignment + released runtime profile + firmware register-map version
   ```

4. Give every generated operation:

   - symbolic register name;
   - physical address or supported API operation;
   - mask and value;
   - source assignment/profile field;
   - valid range or enumeration;
   - ordering dependency;
   - precondition;
   - expected readback mask/value;
   - timeout and failure action.

5. Hash the plan, store its hash in the board snapshot, apply it only after the
   FPGA artifact identity matches, and capture actual readback values.
6. Fail closed if the release, register-map version, carrier revision, or
   runtime profile is unknown.

The existing endpoint initializer writes the endpoint address at
`0x84000008[15:0]`, controls clock/reset bits, and verifies the corresponding
status registers. That is the first concrete register-plan adapter, not proof
that the complete board register set has been defined.

## Release bundle

One released bundle should be used for the whole campaign and identified by a
content manifest. It should include or reference:

- kernel, base device tree, ramdisk, and root filesystem;
- FPGA bitstream and overlay;
- qualified DAPHNE userspace runtime;
- register-map version and released runtime profiles;
- schemas and renderer versions;
- `SHA256SUMS`, source commits, Vivado/PetaLinux versions, and build metadata;
- rollback-compatible previous release information.

The current deploy helper writes only the inactive eMMC slot. It intentionally
does not write QSPI, change U-Boot MAC variables, or change board identity.
Keep QSPI boot-firmware rollout outside the 200-board campaign until it has its
own qualification, A/B recovery procedure, and acceptance gate.

## End-to-end station workflow

### 1. Prepare the campaign

1. Freeze the authoritative carrier list and resolve the 192/200 discrepancy.
2. Freeze the firmware release and artifact-manifest hash.
3. Freeze the register-map/runtime-profile version.
4. Approve IP, hostname, VLAN, timing-endpoint, and network-admission inputs.
5. Initialize the production database and import the real asset CSV.
6. Verify backups, station IDs, operator roles, time synchronization, and
   fixture isolation.

### 2. Establish the manual physical correspondence

1. Put exactly one board in the fixture.
2. Scan the carrier asset/board-number label.
3. Display the database carrier serial and revision for operator confirmation.
4. Read and hash the complete K26 EEPROM.
5. Decode and validate UUID, serial, product, revision, and MAC ID 0.
6. Show the final `board number <-> factory MAC` pair to the operator.
7. Commit both values in one idempotent `discover` operation.

The evidence for this step is the label scan, raw EEPROM hash, decoded values,
station/operator identity, timestamp, and database operation ID.

### 3. Allocate or recover the assignment

Use one transaction to:

- reuse an unchanged existing assignment on retry;
- set production MAC equal to factory MAC under `som_eeprom`;
- allocate or validate unique IP, hostname, VLAN, and timing endpoint;
- bind the immutable release and runtime profile;
- reject every duplicate or conflicting value.

Changing a released assignment requires an explicit revision and reason.

### 4. Render immutable per-board products

Render and hash:

- `board-config-vN.json`;
- `daphne-board.env`;
- hostname and systemd-networkd files;
- deployment `manifest.env`;
- canonical register plan;
- `SHA256SUMS`;
- network-admission candidate.

No generated file is edited by hand. Rendering the same database revision and
release must produce byte-identical products.

### 5. Preflight

Before a write:

- verify scanned asset, EEPROM UUID/MAC, database snapshot hash, SSH host-key
  fingerprint, target host, release manifest, and current boot state;
- confirm the board is on an isolated enrollment network;
- confirm the target is the inactive eMMC slot;
- run deployment and register-plan dry-runs;
- capture current slot and artifact hashes for rollback.

### 6. Deploy

1. Write the common bundle to the inactive eMMC slot.
2. Install only the generated configuration for the scanned asset.
3. Configure a trial boot with automatic fallback.
4. Reboot once.
5. Confirm the trial slot reaches the boot-success gate.
6. Load the expected FPGA application.
7. Apply the generated register plan.
8. Read back every identity layer, artifact hash, and register result.

Do not batch a board that cannot independently fall back or be recovered
locally.

### 7. QA and release

The existing QA recipe requires:

- identity-chain verification;
- artifact-integrity verification;
- three independent cold boots;
- FPGA register access;
- timing lock;
- management-network verification;
- frontend connectivity;
- stability soak.

Qualification does not authorize production networking. A separate reviewer
performs release, after which network automation may consume only the released
MAC/IP/VLAN record.

### 8. Campaign rollout

Use gated waves:

```text
1 instrumented pilot
  -> 5-board pilot
  -> 20-board pre-production wave
  -> repeated controlled waves, no larger than the proven station capacity
```

Stop the campaign on a systemic identity, boot, register, timing, thermal, or
network failure. Never continue merely because some boards passed. Retry uses
the same operation ID and assignment; it must not allocate new values.

## Failure, replacement, and rollback

- Any ambiguous identity or readback moves the board to `quarantined`.
- A failed deployment leaves the prior eMMC slot available and records the
  failure evidence.
- Do not automatically release assignments from a failed board.
- SOM replacement closes the old installation history, removes network
  authorization, reads the new SOM identity, and repeats enrollment.
- Under `som_eeprom`, a SOM replacement changes the production MAC and requires
  network reauthorization.
- A firmware rollback uses a previously qualified common release plus a newly
  rendered snapshot compatible with that release; it does not restore stale
  hand-edited board files.

## Current implementation

### Hardware database repository

Repository and pinned handover revision:

```text
https://github.com/marroyav/hardware-database.git
branch: marroyav/daphne-production-qa
commit: 62151eee6ea67e634d52381c3bfb2eb18495fe85
```

Published on that branch:

- versioned production schemas;
- SQLite and PostgreSQL migrations;
- carrier/SOM separation and lifecycle;
- transactional discovery and allocation;
- uniqueness constraints;
- immutable assignment revisions;
- canonical `daphne.board-config` v1 rendering;
- append-only QA evidence;
- quarantine, service, SOM replacement, qualification, and release;
- a production QA recipe and unit tests.

Primary files:

- `docs/daphne-production-workflow.md`
- `tools/daphne_production_cli.py`
- `tools/daphne_production/`
- `schemas/daphne-production/v1/`
- `migrations/production/`
- `specs/production/daphne-production-qa-v1.json`

### Firmware repository

Repository and branch:

```text
https://github.com/DUNE-DAQ/daphne-firmware.git
branch: marroyav/vivado_2026
2026.1 migration baseline: b780e9c
```

Published on the handover branch:

- board-config v1 renderer;
- board-neutral network configuration;
- factory/expected MAC validation;
- inactive-eMMC-slot deployment with SSH host-key pinning and dry-run;
- rejection of board-stamped MAC setters;
- post-boot identity/configuration checks;
- runtime services for firmware loading, clock-chip setup, endpoint setup,
  Hermes, and `daphneServer`;
- deployment and MAC-policy tests.

Primary files:

- `scripts/deploy/render_board_config.py`
- `scripts/deploy/daphne_deploy.sh`
- `tests/deploy/`
- `tests/petalinux/`
- `docs/daphne-board-enrollment-runbook.md`
- `docs/kria-board-identity-and-production-deployment.md`
- `docs/kr260-petalinux-build-guide.md`

Local Vivado, Vitis, and PetaLinux build trees and generated IP products are
intentionally excluded from Git. Release artifacts must be published through
an immutable artifact bundle with checksums rather than bulk-added from a
developer worktree.

## Verification at handover

The focused suites passed on 2026-07-30:

```text
hardware-database production lifecycle:  6/6 passed
hardware-database staging adapter:        4/4 passed
daphne-firmware deployment renderer:      2/2 passed
daphne-firmware MAC identity policy:      5/5 passed
daphne-firmware repo-local RTL contracts: 11/11 passed
```

The database suite includes a synthetic 200-board uniqueness/validity test.
That proves the allocation model scales to 200 test records; it does not
replace the missing authoritative physical asset list or a station campaign
test.

The native wrapper resolves Vivado and Vitis/SDTGen 2026.1 successfully in
`--dry-run` mode. A licensed clean FPGA build and a complete PetaLinux 2026.1
build remain open gates. The additional STC3 legacy-continuity checker requires
the separate sibling `Daphne_MEZZ` source tree and was not runnable from this
standalone checkout.

## Missing work, in priority order

1. Obtain the authoritative campaign asset list and resolve 192 versus 200.
2. Inventory every per-board runtime/register value currently applied by
   `daphneServer`, Hermes, endpoint, clock-chip, frontend, and QA tooling.
3. Decide which values derive from the asset assignment, which select a
   released profile, and which are common release constants.
4. Define board-config v2 or a separate runtime-config/register-plan v1 schema.
5. Implement deterministic plan rendering, validation, application, and
   readback evidence.
6. Add automated K26 EEPROM capture/decoding to the production station.
7. Qualify one immutable firmware/runtime bundle; the staged `daphneServer`
   payload is currently a verified legacy binary, not reproducible here.
8. Build an idempotent station orchestrator around the existing database,
   renderer, deploy helper, power control, QA tests, and evidence upload.
9. Integrate the approved network allocator/admission interface.
10. Prove recovery, database backup/restore, multi-station concurrency, and
    gated batch rollout.

## First tasks for the next session

Do these before attempting another board write:

1. Run the focused tests in both repositories and record the starting result.
2. Produce a table of all runtime environment variables and hardware register
   writes, including owner, source, allowed range, target, and readback.
3. Draft the new versioned runtime/register contract from that table.
4. Add schema and renderer tests before implementing writes.
5. Exercise the complete flow in dry-run mode with one synthetic record.
6. Repeat on one isolated physical pilot only after review.

Useful starting commands:

```bash
git clone --branch marroyav/daphne-production-qa --single-branch \
  git@github.com:marroyav/hardware-database.git
cd hardware-database
python3 -m unittest -v tests.test_daphne_production
python3 tools/daphne_production_cli.py --help

git clone --branch marroyav/vivado_2026 --single-branch \
  git@github.com:DUNE-DAQ/daphne-firmware.git
cd daphne-firmware
python3 -m unittest discover -s tests/deploy -v
python3 -m unittest discover -s tests/petalinux -v
./scripts/deploy/daphne_deploy.sh --help
```

## Completion criteria

The 200-board workflow is ready only when:

- every real carrier is present exactly once in the controlled asset list;
- every active SOM UUID, serial, and factory MAC is unique;
- every manual board-number/MAC pairing has raw EEPROM evidence;
- one release manifest identifies all common artifacts;
- every board snapshot and register plan is generated and hashed;
- a dry run names the exact board, host, inactive slot, release, configuration,
  and register plan without writing;
- deployed artifacts and all identity layers match expected hashes/values;
- every register write has an approved source and verified readback;
- rollback and quarantine are demonstrated;
- required QA, including three cold boots, passes;
- network authorization occurs only after independent release;
- campaign progress and failures can be reconstructed from append-only evidence.
