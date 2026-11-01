variable "prefix" {
  description = "Short organization prefix. All project IDs and resource names are derived from it, following the same convention as gcp-foundation-bootstrap."
  type        = string
}

variable "cost_center" {
  description = "Cost center label applied to every resource this stage creates."
  type        = string
}

variable "private_dns_domain" {
  description = "Fully qualified private DNS domain hosted on the hub and peered by every spoke. Must end with a dot."
  type        = string
  default     = "gcp.internal."

  validation {
    condition     = endswith(var.private_dns_domain, ".")
    error_message = "private_dns_domain must be a fully qualified domain name ending in a dot."
  }
}

variable "hub_subnets" {
  description = "Subnets of the hub VPC (shared services, VPN and interconnect attachments). Reserve every range in docs/ip-plan.md first."
  type = list(object({
    name          = string
    region        = string
    ip_cidr_range = string
    description   = optional(string, "Terraform-managed.")
  }))

  validation {
    condition     = alltrue([for s in var.hub_subnets : can(cidrhost(s.ip_cidr_range, 0))])
    error_message = "Every ip_cidr_range must be a valid CIDR block."
  }
}
