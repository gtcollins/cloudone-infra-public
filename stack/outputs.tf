output "invoke_url" {
  description = "Open from inside the VPC (or a network CloudOne routes to it) when the API is PRIVATE"
  value       = module.api.invoke_url
}

output "api_authorization" {
  value = module.api.authorization
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "vpc_cidr" {
  value = module.network.vpc_cidr
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "execute_api_vpc_endpoint_id" {
  value = module.api.vpc_endpoint_id
}

output "transit_gateway_attachment_id" {
  value = module.network.transit_gateway_attachment_id
}

output "interface_endpoint_ids" {
  value = module.network.interface_endpoint_ids
}

output "kms_key_arn" {
  value = local.kms_key_arn
}

output "lambda_function_name" {
  value = module.api.function_name
}

output "api_access_log_group" {
  value = module.api.access_log_group
}
