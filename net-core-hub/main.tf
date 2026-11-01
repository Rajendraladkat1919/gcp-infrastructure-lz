locals {
  # Project IDs follow the naming convention established in gcp-foundation-bootstrap
  # 2-network-projects. All are computed from var.prefix — no explicit ID variables.
  hub_project_id      = "${var.prefix}-net-core-hub"
  iac_core_project_id = "${var.prefix}-pr-iac-core"
  spoke_project_ids = {
    prod    = "${var.prefix}-net-shared-prod"
    nonprod = "${var.prefix}-net-shared-nonprod"
  }

  labels = {
    cost-center = var.cost_center
    managed-by  = "terraform"
    repository  = "gcp-infrastructure-lz"
    stage       = "net-core-hub"
    tier        = "network"
  }

  # Google health check and IAP ranges. Documented by Google, stable.
  health_check_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  iap_ranges          = ["35.235.240.0/20"]
}

module "vpc" {
  source                          = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-vpc?ref=5b9de0cf7bb5163ef8d0fa4973f31dd36b6de528"
  project_id                      = local.hub_project_id
  name                            = "${var.prefix}-hub-vpc"
  description                     = "Hub VPC. Managed by Terraform."
  routing_mode                    = "GLOBAL"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = false

  subnets = [
    for s in var.hub_subnets : {
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
    }
  ]
}

# Baseline network firewall policy. Everything not listed is denied by the implied rule.
module "firewall_policy" {
  source    = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-firewall-policy?ref=5b9de0cf7bb5163ef8d0fa4973f31dd36b6de528"
  parent_id = local.hub_project_id
  name      = "${var.prefix}-hub-baseline"
  region    = "global"
  attachments = {
    hub = module.vpc.self_link
  }

  ingress_rules = {
    allow-iap-admin = {
      priority       = 1000
      description    = "SSH and RDP through Identity-Aware Proxy only."
      enable_logging = true
      match = {
        source_ranges = local.iap_ranges
        layer4_configs = [
          { protocol = "tcp", ports = ["22", "3389"] },
        ]
      }
    }
    allow-health-checks = {
      priority       = 1001
      description    = "Google Cloud load balancer and managed instance group health checks."
      enable_logging = false
      match = {
        source_ranges = local.health_check_ranges
        layer4_configs = [
          { protocol = "tcp" },
        ]
      }
    }
  }
}

# NCC hub with MESH topology. Spokes attach from net-shared-prod and net-shared-non-prod.
# See docs/adr/0002-ncc-mesh-with-firewall-isolation.md.
resource "google_network_connectivity_hub" "hub" {
  project     = local.hub_project_id
  name        = "${var.prefix}-hub"
  description = "Landing zone connectivity hub. Managed by Terraform."
  labels      = local.labels
}

resource "google_network_connectivity_group" "default" {
  project     = local.hub_project_id
  hub         = google_network_connectivity_hub.hub.id
  name        = "default"
  description = "Default MESH group. All environment spokes join this group. Managed by Terraform."
  labels      = local.labels

  auto_accept {
    auto_accept_projects = values(local.spoke_project_ids)
  }
}

# The hub VPC itself is also a spoke in the MESH so traffic can transit through the hub.
resource "google_network_connectivity_spoke" "hub_vpc" {
  project     = local.hub_project_id
  name        = "${var.prefix}-hub-core"
  location    = "global"
  description = "Hub VPC spoke. Managed by Terraform."
  labels      = local.labels
  hub         = google_network_connectivity_hub.hub.id
  group       = google_network_connectivity_group.default.id

  linked_vpc_network {
    uri                   = module.vpc.self_link
    include_export_ranges = [for s in var.hub_subnets : s.ip_cidr_range]
  }
}
