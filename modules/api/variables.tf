variable "name" {
  description = "Prefix for resource names, e.g. cloudone-dev"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  description = "Lambda egress and endpoint ingress are limited to this range"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the Lambda and the VPC endpoint"
  type        = list(string)
}

variable "source_dir" {
  description = "Folder containing handler.py (and static/)"
  type        = string
}

variable "environment" {
  description = "Environment variables passed to the Lambda (KMS-encrypted)"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "KMS key for log groups and Lambda environment variables"
  type        = string
}

variable "stage_name" {
  type = string
}

# ── Exposure ────────────────────────────────────────────────────────

variable "endpoint_type" {
  description = "PRIVATE (VPC endpoint only) or REGIONAL (public, commercial practice)"
  type        = string
  default     = "PRIVATE"

  validation {
    condition     = contains(["PRIVATE", "REGIONAL"], var.endpoint_type)
    error_message = "endpoint_type must be PRIVATE or REGIONAL."
  }
}

variable "allowed_ingress_cidrs" {
  description = "Extra networks (beyond the VPC) allowed to reach the private API, e.g. CloudOne user ranges"
  type        = list(string)
  default     = []
}

# ── Authentication ──────────────────────────────────────────────────

variable "authorization" {
  description = "NONE | AWS_IAM | COGNITO_USER_POOLS | CUSTOM"
  type        = string
  default     = "AWS_IAM"

  validation {
    condition     = contains(["NONE", "AWS_IAM", "COGNITO_USER_POOLS", "CUSTOM"], var.authorization)
    error_message = "authorization must be NONE, AWS_IAM, COGNITO_USER_POOLS or CUSTOM."
  }
}

variable "cognito_user_pool_arns" {
  description = "Required when authorization = COGNITO_USER_POOLS"
  type        = list(string)
  default     = []

  validation {
    condition     = var.authorization != "COGNITO_USER_POOLS" || length(var.cognito_user_pool_arns) > 0
    error_message = "cognito_user_pool_arns is required when authorization = COGNITO_USER_POOLS."
  }
}

variable "custom_authorizer_lambda_arn" {
  description = "Lambda authorizer ARN. Required when authorization = CUSTOM."
  type        = string
  default     = null

  validation {
    condition     = var.authorization != "CUSTOM" || var.custom_authorizer_lambda_arn != null
    error_message = "custom_authorizer_lambda_arn is required when authorization = CUSTOM."
  }
}

variable "authorizer_identity_header" {
  description = "Request header carrying the token for COGNITO/CUSTOM auth"
  type        = string
  default     = "Authorization"
}

# ── Logging ─────────────────────────────────────────────────────────

variable "enable_access_logs" {
  description = "Write API access logs to CloudWatch (needs the account-wide API Gateway role)"
  type        = bool
  default     = false
}

variable "create_api_gateway_account_role" {
  description = "Create the account-wide API Gateway CloudWatch role. Only ONE environment per account, and only if CloudOne doesn't manage it."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  type    = number
  default = 365
}

# ── Lambda ──────────────────────────────────────────────────────────

variable "memory_size" {
  type    = number
  default = 128
}

variable "reserved_concurrent_executions" {
  description = "Concurrency reserved for the Lambda (-1 = unreserved)"
  type        = number
  default     = -1
}

variable "code_signing_config_arn" {
  description = "Lambda code signing config (null = off). With an Enforce policy the package must be signed."
  type        = string
  default     = null
}

variable "throttle_burst" {
  type    = number
  default = 50
}

variable "throttle_rate" {
  description = "Steady-state requests per second"
  type        = number
  default     = 100
}

# ── IAM ─────────────────────────────────────────────────────────────

variable "permissions_boundary_arn" {
  description = "IAM permissions boundary attached to roles this module creates (null = none)"
  type        = string
  default     = null
}

variable "iam_role_path" {
  type    = string
  default = "/"
}
