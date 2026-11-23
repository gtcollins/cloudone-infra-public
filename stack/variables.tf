# Every input to the stack. Set values in envs/<env>/terraform.tfvars.
# [Ax] = assumption (ASSUMPTIONS.md)   [Cx] = checklist item (CUSTOMIZE.md)

# ── 1. Environment & region ─────────────────────────────────────────

variable "environment" {
  description = "Environment name; also the API stage name and resource name suffix"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.environment))
    error_message = "environment must be 2-16 lowercase letters, digits or hyphens, e.g. dev, test, prod."
  }
}

variable "aws_region" {
  description = "[A1/C7] AWS region, e.g. us-gov-west-1"
  type        = string
}

variable "use_fips_endpoint" {
  description = "[A2/C8] Use FIPS 140 validated AWS endpoints"
  type        = bool
  default     = true
}

# ── 2. Tags ─────────────────────────────────────────────────────────

variable "required_tags" {
  description = "[A9/C2] Tags CloudOne requires on every resource"
  type        = map(string)

  validation {
    condition     = !anytrue([for v in values(var.required_tags) : upper(v) == "TODO" || v == ""])
    error_message = "Fill in every required_tags value in terraform.tfvars (no TODO or empty values)."
  }
}

# ── 3. IAM ──────────────────────────────────────────────────────────

variable "permissions_boundary_arn" {
  description = "[A10/C4] Permissions boundary for every IAM role created (null = none)"
  type        = string
  default     = null
}

variable "iam_role_path" {
  description = "[A10/C13] Path for every IAM role created"
  type        = string
  default     = "/"
}

# ── 4. Encryption ───────────────────────────────────────────────────

variable "existing_kms_key_arn" {
  description = "[A4/C14] Use this KMS key instead of creating one (null = create). Its policy must allow CloudWatch Logs."
  type        = string
  default     = null
}

variable "kms_deletion_window_days" {
  description = "Recovery window for the created KMS key (7-30)"
  type        = number
  default     = 30
}

# ── 5. Network ──────────────────────────────────────────────────────

variable "create_vpc" {
  description = "[A11/C12] true = build a VPC; false = use existing_vpc_id + existing_private_subnet_ids"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "[A11/C5] CIDR (/16) for a new VPC. Required when create_vpc = true."
  type        = string
  default     = null
}

variable "existing_vpc_id" {
  description = "[C12] VPC to use when create_vpc = false"
  type        = string
  default     = null
}

variable "existing_private_subnet_ids" {
  description = "[C12] Private subnets to use when create_vpc = false"
  type        = list(string)
  default     = []
}

variable "az_count" {
  type    = number
  default = 2
}

variable "transit_gateway_id" {
  description = "[A3/C12] Attach the new VPC to this transit gateway (null = none)"
  type        = string
  default     = null
}

variable "transit_gateway_routes" {
  description = "[A3/C12] CIDRs routed to the transit gateway"
  type        = list(string)
  default     = []
}

variable "interface_endpoints" {
  description = "AWS services reached privately, e.g. [\"logs\", \"xray\", \"sts\"]"
  type        = list(string)
  default     = []
}

variable "enable_internet_gateway" {
  description = "[A3] Internet gateway + public subnets (commercial practice only)"
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "[A3] NAT gateway for outbound internet (commercial practice only)"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "[A6] VPC flow logs (turn off if CloudOne already collects them)"
  type        = bool
  default     = true
}

# ── 6. API ──────────────────────────────────────────────────────────

variable "api_endpoint_type" {
  description = "[A5] PRIVATE for CloudOne; REGIONAL only for commercial practice"
  type        = string
  default     = "PRIVATE"
}

variable "api_allowed_cidrs" {
  description = "[C6] Networks outside the VPC allowed to reach the private API"
  type        = list(string)
  default     = []
}

variable "api_authorization" {
  description = "[A8/C3] NONE | AWS_IAM | COGNITO_USER_POOLS | CUSTOM"
  type        = string
}

variable "cognito_user_pool_arns" {
  description = "[C3] Required when api_authorization = COGNITO_USER_POOLS"
  type        = list(string)
  default     = []
}

variable "custom_authorizer_lambda_arn" {
  description = "[C3] Required when api_authorization = CUSTOM"
  type        = string
  default     = null
}

variable "authorizer_identity_header" {
  description = "[C3] Header carrying the token for COGNITO/CUSTOM auth"
  type        = string
  default     = "Authorization"
}

variable "enable_api_access_logs" {
  description = "[A6/C10] API access logs to CloudWatch"
  type        = bool
  default     = false
}

variable "create_api_gateway_account_role" {
  description = "[C10] Create the account-wide API Gateway logging role (ONE environment per account)"
  type        = bool
  default     = false
}

# ── 7. Lambda ───────────────────────────────────────────────────────

variable "lambda_memory_mb" {
  type    = number
  default = 128
}

variable "lambda_reserved_concurrency" {
  description = "[C19] Reserved concurrency (-1 = unreserved)"
  type        = number
  default     = -1
}

variable "lambda_code_signing_config_arn" {
  description = "[C9] Lambda code signing config ARN (null = off)"
  type        = string
  default     = null
}

# ── 8. Logging ──────────────────────────────────────────────────────

variable "log_retention_days" {
  description = "[A6/C11] CloudWatch log retention"
  type        = number
  default     = 365
}
