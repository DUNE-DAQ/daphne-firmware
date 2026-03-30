# Analog Control

## Scope

Neutral boundary for the board-level configuration path that prepares the
analog front-end and DAC before alignment and acquisition can begin.

This module is about configuration ownership, not datapath behavior. It groups
the control-plane side of the AFE/DAC bring-up into one explicit boundary so
the downstream modules can depend on a clear `config_ready` style contract.

## Imported sources currently involved

- `rtl/afe/*`
- `rtl/dac/*`
- the existing AFE/DAC SPI control feature blocks

## Preconditions that must be explicit

- AFE configuration must be applied before frontend alignment is trusted.
- DAC configuration must be applied before acquisition is considered stable.
- The module should expose a single readiness notion for downstream consumers:
  `config_ready`.

## Dependency ordering

- `control-plane` may request configuration changes.
- `analog-control` applies and reports board-level AFE/DAC configuration.
- `timing-subsystem` must report ready before frontend alignment starts.
- `frontend-boundary` may only align after both configuration and timing are
  ready.
- `trigger-pipeline` and `spy-buffer` only consume data after alignment is
  valid.

## Isolation objective

Keep AFE/DAC configuration explicit and separate from the alignment and trigger
contracts so the later formal layer can prove the readiness chain without
changing the imported behavior.
