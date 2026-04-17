# Developer Manifest

This manifest records the major subsystem provenance and current integration
ownership for the checked-in firmware tree.

It is intentionally pragmatic:

- it is not a replacement for `git log`
- it is not an exhaustive copyright statement
- it is a maintainers' map of who developed or now owns the main subsystem lanes

## Subsystem Attribution

| Subsystem | Developers | Institution | Representative files |
| --- | --- | --- | --- |
| Proto self-trigger and legacy self-trigger foundation | Jamieson Olsen, Jacques Ntahoturi | FNAL | `ip_repo/daphne_ip/rtl/selftrig/stc3.vhd`, `ip_repo/daphne_ip/rtl/selftrig/st40_top.vhd`, `ip_repo/daphne_ip/rtl/selftrig/st20_top.vhd` |
| Filters used by the self-trigger path | Esteban Cristaldo | Bicocca | `ip_repo/daphne_ip/rtl/selftrig/xcorr_import/IIRFilter_afe_integrator_optimized.v`, `ip_repo/daphne_ip/rtl/selftrig/xcorr_import/k_low_pass_filter.v`, `ip_repo/daphne_ip/rtl/selftrig/xcorr_import/hpf_pedestal_recovery_filter_trigger.vhd` |
| Peak descriptors | Ignacio Lopez de Rego, Manuel Arroyave | IFIC, FNAL | `ip_repo/daphne_ip/rtl/selftrig/peak_descriptor_import/`, `rtl/isolated/subsystems/trigger/peak_descriptor_channel.vhd` |
| Cross-correlation self-trigger | Daniel Avila Gomez, Esteban Cristaldo, Manuel Arroyave | EIA, Bicocca, FNAL | `ip_repo/daphne_ip/rtl/selftrig/trig_xc.vhd`, `ip_repo/daphne_ip/rtl/selftrig/eia_selftrig/`, `rtl/isolated/subsystems/trigger/self_trigger_xcorr_channel.vhd` |
| Formal verification, contracts, and integration scaffolding | Manuel Arroyave | FNAL | `formal/`, `formal/contracts/`, `scripts/fusesoc/check_*contract*.sh`, `rtl/isolated/` |

## Notes

- The imported legacy self-trigger tree already carries some original author
  headers. This manifest exists so the current repo also has one canonical
  subsystem-level attribution page.
- Where a repo-owned wrapper exists around imported logic, the wrapper is the
  preferred place to record current integration ownership.
- Formal verification and contract documents in this repo are repo-owned
  integration artifacts, even when they describe imported RTL behavior.
