# 0003: VPN and Interconnect deferred

Status: accepted

## Context

The architecture diagram shows a VPN in the hub. HA VPN needs a real peer gateway address, ASNs, a shared secret process and a BGP design. None exist yet.

## Decision

Do not create placeholder tunnels. `1-network-hub` is ready for them: it has the hub VPC and project, and the vendored library has `net-vpn-ha` and `net-vlan-attachment`.

## Consequences

- No hybrid connectivity until a follow-up PR adds it with real inputs.
- Shared secrets must come from Secret Manager or the provider, never from `.tfvars` in the repository.
