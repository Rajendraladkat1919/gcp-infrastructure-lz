variable "prefix" {
  description = "Short organization prefix. All project IDs are derived from it, following the same convention as gcp-foundation-bootstrap."
  type        = string
}

variable "cost_center" {
  description = "Cost center label applied to every resource this stage creates."
  type        = string
}

variable "private_dns_domain" {
  description = "Fully qualified private DNS domain peered from this spoke to the hub zone. Must end with a dot."
  type        = string
  default     = "gcp.internal."

  validation {
    condition     = endswith(var.private_dns_domain, ".")
    error_message = "private_dns_domain must be a fully qualified domain name ending in a dot."
  }
}

variable "bootstrap_state_bucket" {
  description = "State bucket of gcp-foundation-bootstrap. Read for workload project outputs from its 3-workload-projects stage."
  type        = string
}

variable "lz_state_bucket" {
  description = "State bucket of this repository. Read for hub outputs from the net-core-hub state prefix."
  type        = string
}

variable "environment_supernet" {
  description = "CIDR supernet for this environment. Every subnet must sit inside it. Used to scope NCC route export and firewall deny rules."
  type        = string

  validation {
    condition     = can(cidrhost(var.environment_supernet, 0))
    error_message = "environment_supernet must be a valid CIDR block."
  }
}

variable "other_environment_supernets" {
  description = "Supernets of other environments, denied ingress at priority 100. Enforces prod/non-prod isolation."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.other_environment_supernets : can(cidrhost(cidr, 0))])
    error_message = "Every supernet must be a valid CIDR block."
  }
}

variable "subnets" {
  description = "Workload subnets for this environment's Shared VPC. Reserve every range in docs/ip-plan.md first."
  type = list(object({
    name          = string
    region        = string
    ip_cidr_range = string
    description   = optional(string, "Terraform-managed.")
  }))

  validation {
    condition     = alltrue([for s in var.subnets : can(cidrhost(s.ip_cidr_range, 0))])
    error_message = "Every ip_cidr_range must be a valid CIDR block."
  }
}

variable "proxy_only_subnets" {
  description = "Regional proxy-only subnets for load balancer proxies. Do not grant networkUser on these."
  type = list(object({
    name          = string
    region        = string
    ip_cidr_range = string
    description   = optional(string, "Regional proxy-only subnet.")
  }))
  default = []
}

variable "psa_range" {
  description = "CIDR range for Private Service Access (Cloud SQL, Memorystore). Omit if no managed services are used."
  type        = string
  default     = null
}
