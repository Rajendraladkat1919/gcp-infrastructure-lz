# IP plan

Every range is reserved here **in the same PR** that uses it. Overlap is the one network mistake that cannot be fixed without recreating things.

| Range | Owner | Purpose | Status |
|---|---|---|---|
| `10.0.0.0/24` | `1-network-hub` | Hub shared services (`us-west2`) | planned |
| `10.1.0.0/16` | | Reserved for hub growth (VPN, Interconnect, shared services) | reserved |
| `10.16.0.0/12` | `2-network-spokes` | **Prod supernet** (`environment_supernets.prod`). Exported to NCC. | planned |
| `10.16.0.0/20` | `2-network-spokes` | Prod workloads, `us-west2` | planned |
| `10.16.16.0/23` | `2-network-spokes` | Prod proxy-only subnet, `us-west2`. No `networkUser`. | planned |
| `10.16.32.0/20` | `2-network-spokes` | Prod Private Service Access | planned |
| `10.32.0.0/12` | `2-network-spokes` | **Non-prod supernet** (`environment_supernets.nonprod`). Exported to NCC. | planned |
| `10.32.0.0/20` | `2-network-spokes` | Non-prod workloads, `us-west2` | planned |
| `10.32.16.0/23` | `2-network-spokes` | Non-prod proxy-only subnet, `us-west2`. No `networkUser`. | planned |
| `10.32.32.0/20` | `2-network-spokes` | Non-prod Private Service Access | planned |
| `192.168.0.0/16` | | Reserved for on-premises. Do not use in GCP. | reserved |

Rules:

- Every spoke subnet, proxy-only subnet, and Private Service Access range must sit inside its environment supernet. The variable validation rejects a range outside it.
- Proxy-only subnets are not workload subnets. They do not receive `roles/compute.networkUser`.
- The prod spoke denies ingress from the non-prod supernet and the non-prod spoke denies ingress from the prod supernet, at priority 100, logged.
- The ranges above are **placeholders**. Replace them with the plan agreed with the network team and the on-premises ranges before the first apply.
