output "firewall_policy_id" {
  description = "ID of the hub baseline network firewall policy."
  value       = module.firewall_policy.id
}

output "ncc_hub_id" {
  description = "ID of the NCC hub that spokes attach to."
  value       = google_network_connectivity_hub.hub.id
}

output "ncc_group_id" {
  description = "ID of the NCC default group that spokes join."
  value       = google_network_connectivity_group.default.id
}

output "project_id" {
  description = "Project ID of the hub network project."
  value       = local.hub_project_id
}

output "vpc" {
  description = "Hub VPC name and self link."
  value = {
    name      = module.vpc.name
    self_link = module.vpc.self_link
  }
}
