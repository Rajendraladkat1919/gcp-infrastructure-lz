# 0002: NCC mesh topology, isolation by firewall policy

Status: accepted, review when the vendored `ncc-hub` module supports more than one group

## Context

Network Connectivity Center offers `MESH` and `STAR` topologies. `STAR` gives true isolation (edge spokes reach only the center), but it needs two named groups (`center`, `edge`). The vendored `ncc-hub` module manages exactly one group.

## Decision

Use `MESH` with the `default` group. Prevent prod and non-prod from talking to each other with a priority 100 deny rule in each spoke's network firewall policy, built from `environment_supernets`. Subnets are validated to stay inside their environment supernet.

## Consequences

- Isolation depends on firewall policy, not on routing. A mistaken allow rule with a lower priority number cannot override the deny (priority 100 wins), but a rule with a lower number than 100 could. Reviewers must treat priorities below 100 as a policy change.
- Moving to `STAR` later changes the hub and groups and will disrupt traffic. Plan it as a maintenance window.
