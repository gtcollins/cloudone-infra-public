output "invoke_url" {
  description = "Base URL (only resolvable inside the VPC when endpoint_type = PRIVATE)"
  value       = aws_api_gateway_stage.this.invoke_url
}

output "rest_api_id" {
  value = aws_api_gateway_rest_api.this.id
}

output "vpc_endpoint_id" {
  value = local.private ? aws_vpc_endpoint.execute_api[0].id : null
}

output "function_name" {
  value = aws_lambda_function.api.function_name
}

output "authorization" {
  value = var.authorization
}

output "access_log_group" {
  value = one(aws_cloudwatch_log_group.access[*].name)
}

output "lambda_security_group_id" {
  description = "Allow this SG in future resources (e.g. a database) the Lambda must reach"
  value       = aws_security_group.lambda.id
}
