# Authoritative private zone. Spokes peer to this network rather than hosting a second copy.
module "private_dns" {
  source      = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/dns?ref=5b9de0cf7bb5163ef8d0fa4973f31dd36b6de528"
  project_id  = local.hub_project_id
  name        = "${var.prefix}-private"
  description = "Private zone for ${var.private_dns_domain}. Managed by Terraform."
  labels      = local.labels
  zone_config = {
    domain = var.private_dns_domain
    private = {
      client_networks = [module.vpc.self_link]
    }
  }
}

# Resolves Google APIs to the private.googleapis.com range. VPC Service Controls
# would switch this to restricted.googleapis.com; that perimeter is not built here.
module "dns_response_policy" {
  source      = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/dns-response-policy?ref=5b9de0cf7bb5163ef8d0fa4973f31dd36b6de528"
  project_id  = local.hub_project_id
  name        = "${var.prefix}-googleapis"
  description = "Private Google API names for the hub VPC. Managed by Terraform."
  networks    = { hub = module.vpc.self_link }
  rules = {
    googleapis = {
      dns_name = "*.googleapis.com."
      local_data = {
        A = {
          rrdatas = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"]
        }
      }
    }
  }
}
