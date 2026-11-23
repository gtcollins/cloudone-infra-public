variable "name" {
  description = "Prefix for resource names, e.g. cloudone-dev"
  type        = string
}

# ── Mode ────────────────────────────────────────────────────────────

variable "create_vpc" {
  description = "true = build a VPC; false = use existing_vpc_id + existing_private_subnet_ids"
  type        = bool
  default     = true
}

variable "cidr" {
  description = "CIDR for a new VPC (a /16). Required when create_vpc = true."
  type        = string
  default     = null

  validation {
    condition     = !var.create_vpc || (var.cidr != null && can(cidrhost(var.cidr, 0)) && endswith(coalesce(var.cidr, "x"), "/16"))
    error_message = "When create_vpc = true, cidr must be a valid /16, e.g. 10.10.0.0/16."
  }
}

variable "existing_vpc_id" {
  description = "VPC to use when create_vpc = false"
  type        = string
  default     = null

  validation {
    condition     = var.create_vpc || var.existing_vpc_id != null
    error_message = "existing_vpc_id is required when create_vpc = false."
  }
}

variable "existing_private_subnet_ids" {
  description = "Private subnets to use when create_vpc = false"
  type        = list(string)
  default     = []

  validation {
    condition     = var.create_vpc || length(var.existing_private_subnet_ids) > 0
    error_message = "existing_private_subnet_ids is required when create_vpc = false."
  }
}

variable "az_count" {
  description = "Availability zones for new subnets (create_vpc = true)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count must be between 1 and 3."
  }
}

# ── Connectivity ────────────────────────────────────────────────────

variable "transit_gateway_id" {
  description = "Attach the new VPC to this transit gateway (null = no attachment). Only with create_vpc = true."
  type        = string
  default     = null
}

variable "transit_gateway_routes" {
  description = "CIDRs routed from private subnets to the transit gateway, e.g. [\"10.0.0.0/8\"] or [\"0.0.0.0/0\"]"
  type        = list(string)
  default     = []

  validation {
    condition     = !(var.enable_nat_gateway && contains(var.transit_gateway_routes, "0.0.0.0/0"))
    error_message = "A 0.0.0.0/0 transit gateway route conflicts with enable_nat_gateway = true. Pick one default route."
  }
}

variable "interface_endpoints" {
  description = "AWS services to reach privately, e.g. [\"logs\", \"xray\", \"sts\"]. execute-api is handled by the api module."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.interface_endpoints, "execute-api")
    error_message = "Don't list execute-api here - the api module creates that endpoint."
  }
}

variable "enable_internet_gateway" {
  description = "Create an internet gateway and public subnets (commercial practice only; off for CloudOne)"
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Give private subnets outbound internet through a NAT gateway (needs enable_internet_gateway)"
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_nat_gateway || var.enable_internet_gateway
    error_message = "enable_nat_gateway requires enable_internet_gateway = true."
  }
}

# ── Logging / IAM ───────────────────────────────────────────────────

variable "enable_flow_logs" {
  description = "Create VPC flow logs (turn off if CloudOne already collects them for this VPC)"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key used to encrypt the flow log group"
  type        = string
}

variable "flow_log_retention_days" {
  type    = number
  default = 365
}

variable "permissions_boundary_arn" {
  description = "IAM permissions boundary attached to roles this module creates (null = none)"
  type        = string
  default     = null
}

variable "iam_role_path" {
  type    = string
  default = "/"
}
