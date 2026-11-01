# 0001: Two stages, state in a separate bucket, folder ids read from bootstrap

Status: accepted

## Context

Hub and spokes change at different speeds, and the spokes depend on the hub. Folder ids, workload project ids and numbers are created by `gcp-foundation-bootstrap`.

## Decision

Two stages (`1-network-hub`, `2-network-spokes`), applied in the order of `config/stages.txt`, each with its own state prefix (`lz/<stage>`) in the LZ state bucket. Data from the bootstrap repository is read through `terraform_remote_state` from its state bucket, read-only. Names that both repositories must agree on live in `modules/naming`.

## Consequences

- The LZ plan and apply identities can read the bootstrap bucket but never write to it.
- Bootstrap output names are an API.
- A workload project that does not exist yet cannot be attached. Apply bootstrap stage 3 first.
