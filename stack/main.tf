# The CloudOne stack: wires the modules together. Contains NO environment
# values. Those live in envs/<env>/terraform.tfvars and envs/<env>/backend.hcl.
# Run it with:  ./scripts/tf.sh <env> <command>

locals {
  name        = "cloudone-${var.environment}"
  kms_key_arn = var.existing_kms_key_arn != null ? var.existing_kms_key_arn : one(module.kms[*].key_arn)
}

# Skipped when CloudOne provides a shared key (existing_kms_key_arn).
module "kms" {
  source = "../modules/kms"
  count  = var.existing_kms_key_arn == null ? 1 : 0

  name                    = local.name
  deletion_window_in_days = var.kms_deletion_window_days
}

module "network" {
  source = "../modules/network"

  name                        = local.name
  create_vpc                  = var.create_vpc
  cidr                        = var.vpc_cidr
  existing_vpc_id             = var.existing_vpc_id
  existing_private_subnet_ids = var.existing_private_subnet_ids
  az_count                    = var.az_count
  transit_gateway_id          = var.transit_gateway_id
  transit_gateway_routes      = var.transit_gateway_routes
  interface_endpoints         = var.interface_endpoints
  enable_internet_gateway     = var.enable_internet_gateway
  enable_nat_gateway          = var.enable_nat_gateway
  enable_flow_logs            = var.enable_flow_logs
  kms_key_arn                 = local.kms_key_arn
  flow_log_retention_days     = var.log_retention_days
  permissions_boundary_arn    = var.permissions_boundary_arn
  iam_role_path               = var.iam_role_path
}

module "api" {
  source = "../modules/api"

  name                  = local.name
  vpc_id                = module.network.vpc_id
  vpc_cidr              = module.network.vpc_cidr
  subnet_ids            = module.network.private_subnet_ids
  source_dir            = "${path.module}/../app/api"
  stage_name            = var.environment
  kms_key_arn           = local.kms_key_arn
  endpoint_type         = var.api_endpoint_type
  allowed_ingress_cidrs = var.api_allowed_cidrs

  authorization                = var.api_authorization
  cognito_user_pool_arns       = var.cognito_user_pool_arns
  custom_authorizer_lambda_arn = var.custom_authorizer_lambda_arn
  authorizer_identity_header   = var.authorizer_identity_header

  enable_access_logs              = var.enable_api_access_logs
  create_api_gateway_account_role = var.create_api_gateway_account_role
  log_retention_days              = var.log_retention_days

  memory_size                    = var.lambda_memory_mb
  reserved_concurrent_executions = var.lambda_reserved_concurrency
  code_signing_config_arn        = var.lambda_code_signing_config_arn

  permissions_boundary_arn = var.permissions_boundary_arn
  iam_role_path            = var.iam_role_path

  environment = {
    ENVIRONMENT = var.environment
  }
}
