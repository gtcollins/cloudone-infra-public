output "vpc_id" {
  value = local.vpc_id
}

output "vpc_cidr" {
  value = local.vpc_cidr
}

output "private_subnet_ids" {
  value = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Empty unless enable_internet_gateway = true"
  value       = aws_subnet.public[*].id
}

output "transit_gateway_attachment_id" {
  value = one(aws_ec2_transit_gateway_vpc_attachment.this[*].id)
}

output "interface_endpoint_ids" {
  description = "Map of service name to endpoint ID"
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}
