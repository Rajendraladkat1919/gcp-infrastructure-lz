# The Cloud DNS service agent of this spoke must be allowed to peer at the hub VPC.
resource "google_project_service_identity" "dns" {
  provider = google-beta
  project  = local.spoke_project_id
  service  = "dns.googleapis.com"
}

resource "google_project_iam_member" "dns_peer" {
  project = data.terraform_remote_state.hub.outputs.project_id
  role    = "roles/dns.peer"
  member  = "serviceAccount:${google_project_service_identity.dns.email}"
}

module "private_dns" {
  source      = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/dns?ref=5b9de0cf7bb5163ef8d0fa4973f31dd36b6de528"
  project_id  = local.spoke_project_id
  name        = "${var.prefix}-${local.env_code}-private"
  description = "Peers ${var.private_dns_domain} to the hub zone. Managed by Terraform."
  labels      = local.labels
  zone_config = {
    domain = var.private_dns_domain
    peering = {
      client_networks = [module.vpc.self_link]
      peer_network    = data.terraform_remote_state.hub.outputs.vpc.self_link
    }
  }
  depends_on = [google_project_iam_member.dns_peer]
}

module "dns_response_policy" {
  source      = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/dns-response-policy?ref=5b9de0cf7bb5163ef8d0fa4973f31dd36b6de528"
  project_id  = local.spoke_project_id
  name        = "${var.prefix}-${local.env_code}-googleapis"
  description = "Private Google API names for the ${local.environment} spoke. Managed by Terraform."
  networks    = { spoke = module.vpc.self_link }
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
