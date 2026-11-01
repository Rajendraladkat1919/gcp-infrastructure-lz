# Controls

Network controls this repository enforces in code, and what it leaves out. Organization-wide controls (organization policy, audit logging, identity) are in `gcp-foundation-bootstrap/docs/controls.md`. This is a mapping aid for audits, **not** a certification.

## Enforced in code

### Change management

Identical to `gcp-foundation-bootstrap`: two approvals with a code owner, signed commits, linear history, mandatory pre-commit and CI checks (`pre-commit`, `plan-gate`, `pr-title`, `dependency-review`), plan on every PR, human approval through the `production` environment, serial applies, nightly drift detection, pinned Terraform, providers, actions and modules.

### Network

| Control | Implementation | Where |
|---|---|---|
| No default network, no auto-mode VPC | `auto_create_subnetworks = false`; organization policy `compute.skipDefaultNetworkCreation` (bootstrap) | `1-network-hub`, `2-network-spokes` |
| Production and non-production isolated | Spoke firewall policy denies ingress from the other environment's supernet at priority 100, with logging | `2-network-spokes/main.tf` |
| Subnets stay in their environment's range | Variable validation against `environment_supernets` | `2-network-spokes/variables.tf` |
| Only IAP for admin access | Firewall policy allows SSH and RDP only from `35.235.240.0/20`, logged. Nothing else is allowed in by default (implied deny) | both stages |
| No public IPs on VMs | Organization policy `compute.vmExternalIpAccess` (bootstrap). Internet egress is through Cloud NAT only | `2-network-spokes/main.tf` |
| Private Google access | `enable_private_access = true` on every subnet | both stages |
| Network visibility | VPC flow logs on every subnet (5 s aggregation, 50% sampling, all metadata); Cloud NAT error logging; firewall rule logging on admin and cross-environment rules | both stages |
| Least privilege on shared networks | Workload deployers and the Google APIs service agent get `roles/compute.networkUser` **per workload subnet**, never on the project, the proxy-only subnet, or the Private Service Access range | `2-network-spokes/main.tf` |
| Private DNS | Hub hosts `gcp.internal.`. Each spoke peers to that zone. A response policy resolves `*.googleapis.com` to the private Google API addresses | `1-network-hub/dns.tf`, `2-network-spokes/dns.tf` |
| NCC exports the environment supernet only | Spoke attachments set `include_export_ranges` to `environment_supernets`. The hub exports its configured subnet ranges | `1-network-hub/main.tf`, `2-network-spokes/main.tf` |
| Network projects cannot be deleted by a stray apply | `deletion_policy = "PREVENT"` on the host projects | bootstrap `2-network-projects` |
| Shared VPC attachment is code, not a console click | `google_compute_shared_vpc_service_project` is built from the bootstrap workload output. The host flag is set by bootstrap stage 4 | `2-network-spokes/main.tf` |

## Exceptions

| Id | Exception | Reason | Owner | Review |
|---|---|---|---|---|
| EX-1 | NCC hub uses the `MESH` topology, so every spoke could route to every other spoke | The vendored `ncc-hub` module manages one group. Isolation is enforced by firewall policy instead. See ADR 0002. | Network team | Every 6 months |
| EX-2 | Flow logs sample at 50% with all metadata | Cost versus forensic value. Lower the sampling per subnet only with a written risk acceptance. | Security | Every year |
| EX-3 | `dev-terraform-execute` holds `roles/compute.xpnAdmin` on the Infrastructure and Workloads folders | Required to attach workload projects to the Shared VPC hosts. The hosts themselves are enabled by bootstrap stage `2-network-projects`. Granted in bootstrap `1-org`. | Platform engineering | Every 6 months |
| EX-4 | Module sources are pinned by release tag, not by commit hash (checkov `CKV_TF_1` is skipped) | The modules repository is internal, and a commit hash cannot be known before the vendored repository is first pushed. Mitigation: a tag ruleset on `v*` in `gcp-terraform-module` (no deletion, no update), and re-vendoring only by reviewed PR. | Platform engineering | When the modules repository exists, then every year |

## Not covered here

- Hybrid connectivity (VPN, Interconnect), centralized egress inspection and VPC Service Controls (see README)
- Workload-specific firewall rules and load balancers, owned by the workload repositories
- GKE and other service-specific agent grants on Shared VPC subnets. Add them next to the `network_users` list when the first such workload arrives.
- Alerting on flow logs, firewall logs and NCC state
- A tested disaster recovery plan for the hub
