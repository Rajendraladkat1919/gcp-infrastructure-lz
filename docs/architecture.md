# Architecture

## Two-repo model

The landing zone is built by two repositories applied in sequence. Neither can substitute for the other.

```
gcp-foundation-bootstrap          gcp-infrastructure-lz
────────────────────────          ──────────────────────────────────────
Creates the GCP skeleton:         Fills in the networking inside that skeleton:
  org policies                      Hub VPC, NCC hub-and-spoke mesh
  folder hierarchy                  Private DNS + googleapis response policies
  core projects                     Cloud NAT per region
  service accounts                  Shared VPC host enablement
  state buckets                     Subnet IAM (networkUser per workload project)
  WIF OIDC pool                     Workload project Shared VPC attachments
  3 empty network projects
  workload projects
```

The bootstrap output is the input to the LZ. No value is hardcoded in both — every shared identifier flows through Terraform remote state or GitHub Actions variables.

---

## Deployed resource hierarchy

```
organizations/351904638555  (platform-engineering.site)
│
├── pe-pr-iac-core   [Root]  Terraform state, CMEK, SAs, WIF pool
├── pe-pr-billing    [Root]  Billing export → BigQuery
├── pe-pr-logging    [Root]  Central audit log + VPC flow log buckets
│
├── Infrastructure  (259727004942)
│   └── Network     (182477435761)
│       ├── pe-net-core-hub        NCC hub, hub VPC, DNS zone, baseline firewall
│       ├── pe-net-shared-prod     Shared VPC host — production
│       └── pe-net-shared-nonprod  Shared VPC host — non-production
│
└── Workloads       (90652712502)
    ├── Prod         (386881948783)
    │   └── <workload projects>  service-attached to pe-net-shared-prod
    └── NonProd      (613342496073)
        └── <workload projects>  service-attached to pe-net-shared-nonprod
```

---

## What each stage builds

### gcp-foundation-bootstrap

| Stage | Creates |
|-------|---------|
| `0-core-projects` | `pe-pr-iac-core`, `pe-pr-billing`, `pe-pr-logging`; CMEK key; bootstrap + lz state buckets; `platform-tf-admin-sa`, `network-tf-infra-sa`; GitHub OIDC WIF pool + provider |
| `1-org` | Infrastructure + Workloads folder trees; Network, Prod, NonProd sub-folders; 29 org policies; 4 org-level log sinks → audit and flow log buckets; XSIAM Pub/Sub; group IAM bindings |
| `2-network-projects` | Three empty projects in `Infrastructure/Network`: `pe-net-core-hub`, `pe-net-shared-prod`, `pe-net-shared-nonprod`. Enables required APIs, marks shared-prod and shared-nonprod as Shared VPC hosts, grants `network-tf-infra-sa` network/DNS/NCC/firewall roles on all three. |
| `4-workload-projects` | One project per YAML in `data/projects/`. Each gets: a Workload SA, CMEK key, Terraform state bucket, and IAM for both the workload and bootstrap SAs. Workload projects are placed in `Workloads/Prod` or `Workloads/NonProd` based on the YAML `environment` field. |

### gcp-infrastructure-lz

| Stage | Project | Builds |
|-------|---------|--------|
| `net-core-hub` | `pe-net-core-hub` | Hub VPC; NCC hub + default MESH group (auto-accepts both spoke projects); hub VPC NCC spoke; baseline firewall policy (IAP, health checks); private DNS zone for `gcp.internal.`; googleapis response policy |
| `net-shared-non-prod` | `pe-net-shared-nonprod` | Nonprod Shared VPC with subnets, proxy-only subnet, PSA range; subnet IAM (`networkUser`) for each workload project's Terraform SA + Google APIs agent; Cloud NAT per region; NCC spoke joining hub MESH group; DNS peering zone → hub; googleapis response policy; Shared VPC service project attachments for all nonprod workload projects; deny-prod ingress at priority 100 |
| `net-shared-prod` | `pe-net-shared-prod` | Same as nonprod for production; deny-nonprod ingress at priority 100 |

---

## Networking topology

```
                        pe-net-core-hub
         ┌──────────────────────────────────────────────┐
         │  Hub VPC                NCC Hub (MESH)        │
         │  10.0.0.0/24            group: default        │
         │  hub-shared-us-west2    auto-accept:          │
         │  (flow logs, PGA)       pe-net-shared-prod    │
         │                         pe-net-shared-nonprod │
         │  Private DNS            (hub VPC is also      │
         │  gcp.internal.          a spoke in the mesh)  │
         └───────────────┬───────────────┬───────────────┘
                         │ NCC MESH      │ NCC MESH
                DNS peer │ transit       │ transit
                         │               │
   pe-net-shared-nonprod │               │ pe-net-shared-prod
  ┌──────────────────────┴──┐   ┌────────┴────────────────────┐
  │  Shared VPC host        │   │  Shared VPC host            │
  │  10.32.0.0/12 supernet  │   │  10.16.0.0/12 supernet      │
  │                         │   │                             │
  │  subnets:               │   │  subnets:                   │
  │  10.32.0.0/20 workloads │   │  10.16.0.0/20 workloads     │
  │  10.32.16.0/23 proxy    │   │  10.16.16.0/23 proxy        │
  │  10.32.32.0/20 PSA      │   │  10.16.32.0/20 PSA          │
  │                         │   │                             │
  │  networkUser granted to │   │  networkUser granted to     │
  │  nonprod workload SAs   │   │  prod workload SAs          │
  │                         │   │                             │
  │  Cloud NAT, DNS peer    │   │  Cloud NAT, DNS peer        │
  │  DENY 10.16.0.0/12 @100 │   │  DENY 10.32.0.0/12 @100    │
  └─────────────────────────┘   └─────────────────────────────┘
            ▲                               ▲
            │ Shared VPC                    │ Shared VPC
    ┌───────┴───────┐               ┌───────┴───────┐
    │ NonProd       │               │ Prod           │
    │ workload      │               │ workload       │
    │ projects      │               │ projects       │
    └───────────────┘               └───────────────┘
```

---

## State wiring

The LZ never writes to the bootstrap state bucket — it only reads from it.

```
Bootstrap state bucket  (pe-pr-tfstate-bootstrap)
  bootstrap/1-org                → folder_ids          ← 2-network-projects reads
  bootstrap/3-workload-projects  → projects             ← net-shared-nonprod reads
                                   project_id             ← net-shared-prod reads
                                   project_number
                                   environment
                                   terraform_executor_email

LZ state bucket  (pe-pr-tfstate-lz)
  terraform/state/net-core-hub
    outputs: ncc_hub_id          ← net-shared-nonprod reads
             ncc_group_id        ← net-shared-prod reads
             vpc.self_link       (DNS peering peer network)
             project_id          (DNS peer IAM target)

  terraform/state/net-shared-nonprod
    outputs: project_id, vpc, subnets, service_projects

  terraform/state/net-shared-prod
    outputs: project_id, vpc, subnets, service_projects
```

---

## Identity and CI/CD

```
GitHub Actions job
  declares environment: production or nonprod
       │
       │  OIDC token
       │  claims: repository = org/gcp-infrastructure-lz
       │          environment = production | nonprod
       ▼
WIF Pool (pe-pr-iac-core / pool: github)
  provider: github-actions
  attribute_condition: repository_owner == 'ORG'
       │
       │  principalSet matches attribute.repository
       ▼
network-tf-infra-sa@pe-pr-iac-core.iam.gserviceaccount.com
       │
       ├─ roles/storage.objectAdmin    → pe-pr-tfstate-lz   (reads + writes own state)
       ├─ roles/storage.objectViewer   → pe-pr-tfstate-bootstrap  (reads workload outputs)
       │
       └─ Granted on each network project (by gcp-foundation-bootstrap 2-network-projects):
            roles/compute.networkAdmin
            roles/compute.securityAdmin
            roles/compute.xpnAdmin
            roles/dns.admin
            roles/networkconnectivity.admin
            roles/servicenetworking.networksAdmin
            roles/serviceusage.serviceUsageConsumer
```

### GitHub Actions environment gates

| Stage | GitHub Environment | Effect |
|-------|-------------------|--------|
| `net-core-hub` | `production` | Requires approval; deploy from `main` only |
| `net-shared-prod` | `production` | Same gate — prod spoke waits for hub |
| `net-shared-non-prod` | `nonprod` | No approval gate; deploys as soon as plan passes |

`apply-nonprod` and `apply-prod` run in parallel after `apply-hub` completes.

---

## Apply order across both repos

```
gcp-foundation-bootstrap
  0-core-projects  ──(manual, once)──► state buckets, SAs, WIF
       │
  1-org  ──────────────────────────► folders, org policies, log sinks
       │
  2-network-projects  ─────────────► pe-net-core-hub, pe-net-shared-prod,
       │                              pe-net-shared-nonprod  (empty shells + IAM)
       │
       ▼
gcp-infrastructure-lz
  net-core-hub  ───────────────────► Hub VPC, NCC hub, DNS zone, firewall
       │
       ├── net-shared-non-prod  ───► Nonprod Shared VPC, NCC spoke, Cloud NAT,
       │                             DNS peer, Shared VPC attachments
       └── net-shared-prod  ──────► Prod Shared VPC, NCC spoke, Cloud NAT,
                                     DNS peer, Shared VPC attachments
       │
       ▼
gcp-foundation-bootstrap
  4-workload-projects  ────────────► Workload projects (Shared VPC attachment
                                      prepared by net-shared-* stages above)
```

---

## GitHub Actions variables required in gcp-infrastructure-lz

Set once after `gcp-foundation-bootstrap` stages 0 and 2 are applied.

| Variable | Source | Value (this deployment) |
|----------|--------|------------------------|
| `TF_SA` | `0-core-projects` → `automation_service_accounts.infra` | `network-tf-infra-sa@pe-pr-iac-core.iam.gserviceaccount.com` |
| `WIF_PROVIDER` | `0-core-projects` → `wif_provider` | verify: `terraform -chdir=0-core-projects output wif_provider` |
| `TF_STATE_BUCKET` | `0-core-projects` → `lz_state_config.state_bucket` | `pe-pr-tfstate-lz` |
| `TF_BOOTSTRAP_STATE_BUCKET` | `0-core-projects` → `lz_state_config.bootstrap_state_bucket` | `pe-pr-tfstate-bootstrap` |
| `TF_IAC_PROJECT_ID` | `0-core-projects` → `core_projects.iac_core` | `pe-pr-iac-core` |
| `TF_HUB_PROJECT_ID` | `2-network-projects` → `projects["hub"].project_id` | `pe-net-core-hub` |
| `TF_SPOKE_PROJECT_ID_PROD` | `2-network-projects` → `projects["shared-prod"].project_id` | `pe-net-shared-prod` |
| `TF_SPOKE_PROJECT_ID_NONPROD` | `2-network-projects` → `projects["shared-nonprod"].project_id` | `pe-net-shared-nonprod` |
