locals {
  environment = "prod"
  env_code    = "pr"

  # Project IDs derived from var.prefix — same convention as gcp-foundation-bootstrap 2-network-projects.
  spoke_project_id    = "${var.prefix}-net-shared-prod"
  iac_core_project_id = "${var.prefix}-pr-iac-core"

  labels = {
    cost-center = var.cost_center
    environment = local.environment
    managed-by  = "terraform"
    repository  = "gcp-infrastructure-lz"
    stage       = "net-shared-prod"
    tier        = "network"
  }

  # Google health check and IAP ranges. Documented by Google, stable.
  health_check_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  iap_ranges          = ["35.235.240.0/20"]
}

# Workload project outputs from gcp-foundation-bootstrap stage 3. Read-only.
data "terraform_remote_state" "workloads" {
  backend = "gcs"
  config = {
    bucket = var.bootstrap_state_bucket
    prefix = "bootstrap/3-workload-projects"
  }
}

# Hub outputs from net-core-hub. Read-only.
data "terraform_remote_state" "hub" {
  backend = "gcs"
  config = {
    bucket = var.lz_state_bucket
    prefix = "terraform/state/net-core-hub"
  }
}

locals {
  all_workload_projects = data.terraform_remote_state.workloads.outputs.projects

  # Filter to workload projects for this environment only.
  env_projects = {
    for k, p in local.all_workload_projects : k => p if p.environment == local.environment
  }

  # networkUser on workload subnets: the workload terraform executor SA and the Google APIs
  # service agent per project. Mirrors what gcp-terraform-module/modules/naming provides.
  network_users = flatten([
    for p in values(local.env_projects) : [
      "serviceAccount:${p.terraform_executor_email}",
      "serviceAccount:${p.project_number}@cloudservices.gserviceaccount.com",
    ]
  ])

  # One Cloud NAT per distinct region found in subnets.
  nat_regions = {
    for region in distinct([for s in var.subnets : s.region]) :
    region => { region = region }
  }
}

# Attach workload (service) projects to this Shared VPC host.
resource "google_compute_shared_vpc_service_project" "workload" {
  for_each = local.env_projects

  host_project    = local.spoke_project_id
  service_project = each.value.project_id
}

module "vpc" {
  source                  = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-vpc?ref=5b9de0cf7bb5163ef8d0fa4973f31dd36b6de528"
  project_id              = local.spoke_project_id
  name                    = "${var.prefix}-${local.env_code}-spoke-vpc"
  description             = "Shared VPC for ${local.environment} workloads. Managed by Terraform."
  routing_mode            = "GLOBAL"
  auto_create_subnetworks = false

  subnets = [
    for s in var.subnets : {
      name                  = s.name
      region                = s.region
      ip_cidr_range         = s.ip_cidr_range
      description           = s.description
      enable_private_access = true
      flow_logs_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling        = 0.5
        metadata             = "INCLUDE_ALL_METADATA"
      }
      iam = length(local.network_users) > 0 ? {
        "roles/compute.networkUser" = local.network_users
      } : {}
    }
  ]

  # Proxy-only subnets are for load balancer proxies. They must not receive networkUser.
  subnets_proxy_only = [
    for s in var.proxy_only_subnets : {
      name          = s.name
      region        = s.region
      ip_cidr_range = s.ip_cidr_range
      description   = s.description
      active        = true
    }
  ]

  psa_configs = var.psa_range == null ? [] : [
    { ranges = { psa = var.psa_range } }
  ]
}

module "firewall_policy" {
  source    = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-firewall-policy?ref=5b9de0cf7bb5163ef8d0fa4973f31dd36b6de528"
  parent_id = local.spoke_project_id
  name      = "${var.prefix}-${local.env_code}-spoke-baseline"
  region    = "global"
  attachments = {
    spoke = module.vpc.self_link
  }

  ingress_rules = merge(
    {
      allow-iap-admin = {
        priority       = 1000
        description    = "SSH and RDP through Identity-Aware Proxy only."
        enable_logging = true
        match = {
          source_ranges = local.iap_ranges
          layer4_configs = [{ protocol = "tcp", ports = ["22", "3389"] }]
        }
      }
      allow-health-checks = {
        priority       = 1001
        description    = "Google Cloud load balancer and managed instance group health checks."
        enable_logging = false
        match = {
          source_ranges  = local.health_check_ranges
          layer4_configs = [{ protocol = "tcp" }]
        }
      }
    },
    length(var.other_environment_supernets) > 0 ? {
      deny-other-environments = {
        priority       = 100
        action         = "deny"
        description    = "Production and non-production never talk to each other."
        enable_logging = true
        match          = { source_ranges = var.other_environment_supernets }
      }
    } : {}
  )
}

module "nat" {
  source         = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-cloudnat?ref=5b9de0cf7bb5163ef8d0fa4973f31dd36b6de528"
  for_each       = local.nat_regions
  project_id     = local.spoke_project_id
  region         = each.value.region
  name           = "${var.prefix}-${local.env_code}-nat-${each.value.region}"
  router_network = module.vpc.name
  logging_filter = "ERRORS_ONLY"
}

# Attach this spoke VPC to the hub. The hub auto-accepts because spoke_project_id is in
# local.spoke_project_ids on the net-core-hub side.
resource "google_network_connectivity_spoke" "vpc" {
  project     = local.spoke_project_id
  name        = "${var.prefix}-${local.env_code}-spoke"
  location    = "global"
  description = "Spoke for ${local.environment} workloads. Managed by Terraform."
  labels      = local.labels
  hub         = data.terraform_remote_state.hub.outputs.ncc_hub_id
  group       = data.terraform_remote_state.hub.outputs.ncc_group_id

  linked_vpc_network {
    uri = module.vpc.self_link
    # Export the environment supernet, not every future subnet. PSA and proxy-only
    # ranges sit inside it. On-premises ranges stay out until a peer exists.
    include_export_ranges = [var.environment_supernet]
  }
}
