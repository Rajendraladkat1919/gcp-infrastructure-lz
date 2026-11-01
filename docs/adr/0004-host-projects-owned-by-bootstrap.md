# 0004: Host projects are created by the bootstrap repository

Status: accepted

Supersedes the project-creation part of ADR 0001. Stages, state prefixes and reading workload projects from bootstrap state are unchanged.

## Context

The hub and both Shared VPC hosts belong under the Network folder. Creating them in this repository put the prod and non-prod hosts under Infrastructure / Prod and Infrastructure / Non-Prod, and made this repository the project creator.

## Decision

`gcp-foundation-bootstrap` stage `2-network-projects` creates `<prefix>-pr-net-core`, `<prefix>-prod-net-spoke` and `<prefix>-non-prod-net-spoke` in the Network folder, and enables the two spokes as Shared VPC hosts. This repository builds VPCs and attaches service projects in those existing projects. Project ids stay in `gcp-terraform-module/modules/naming`, which both repositories call.

## Consequences

- Apply bootstrap stage 4 before either stage here.
- This repository no longer needs `1-org.folder_ids` or a billing account.
- `dev-terraform-execute` is not owner of the host projects. Its network roles are granted on the Network folder by bootstrap stage 1. See bootstrap ADR 0006.
