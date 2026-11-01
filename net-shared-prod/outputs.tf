output "project_id" {
  description = "Shared VPC host project ID for the prod environment."
  value       = local.spoke_project_id
}

output "service_projects" {
  description = "Workload project IDs attached to this Shared VPC host."
  value       = [for p in values(local.env_projects) : p.project_id]
}

output "subnets" {
  description = "Subnet self links of the prod spoke VPC."
  value       = module.vpc.subnet_self_links
}

output "vpc" {
  description = "Name and self link of the prod spoke VPC."
  value = {
    name      = module.vpc.name
    self_link = module.vpc.self_link
  }
}
