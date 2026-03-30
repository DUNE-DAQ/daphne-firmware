# Spy Buffer Contract

Status: documentation target first

## Scope

- capture enable
- capture gating
- safe behavior before acquisition readiness

## Assumptions

- spy capture remains a debug/observation path, not an independent readiness
  source
- upstream configuration, timing, and alignment predicates are authoritative

## Guarantees to define before proof work

- no meaningful capture enable while readiness conditions are false
- disabled capture does not perturb the main acquisition path
