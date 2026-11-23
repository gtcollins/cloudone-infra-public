# Network for the CloudOne stack. Two modes:
#   create_vpc = true   build a VPC with private subnets (default)
#   create_vpc = false  use a VPC + subnets CloudOne already built
# [ASSUMPTION A3] No direct internet: CloudOne provides connectivity (e.g. a
# transit gateway). Internet gateway / NAT exist only for commercial practice.

data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394:Only the first az_count zones are used (slice below), so new AZs don't change the result
  state = "available"
}

data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  id    = var.existing_vpc_id
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  vpc_id             = var.create_vpc ? aws_vpc.this[0].id : var.existing_vpc_id
  vpc_cidr           = var.create_vpc ? aws_vpc.this[0].cidr_block : data.aws_vpc.existing[0].cidr_block
  private_subnet_ids = var.create_vpc ? aws_subnet.private[*].id : var.existing_private_subnet_ids

  private_count = var.create_vpc ? var.az_count : 0
  create_igw    = var.create_vpc && var.enable_internet_gateway
  public_count  = local.create_igw ? var.az_count : 0
  create_nat    = local.create_igw && var.enable_nat_gateway
  attach_tgw    = var.create_vpc && var.transit_gateway_id != null
}

# ── VPC and private subnets (create_vpc = true) ────────────────────

resource "aws_vpc" "this" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # required for interface endpoint private DNS

  tags = { Name = "${var.name}-vpc" }
}

# /16 VPC -> /24 subnets. Private: x.x.10-19.0, public (optional): x.x.0-9.0
resource "aws_subnet" "private" {
  count = local.private_count

  vpc_id            = aws_vpc.this[0].id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr, 8, count.index + 10)

  tags = { Name = "${var.name}-private-${local.azs[count.index]}", Tier = "private" }
}

resource "aws_route_table" "private" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  tags   = { Name = "${var.name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = local.private_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# Strip all rules from the default security group so nothing uses it by accident.
resource "aws_default_security_group" "this" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  tags   = { Name = "${var.name}-default-deny" }
}

# ── Transit gateway (CloudOne connectivity) ────────────────────────
# [ASSUMPTION A3] If the TGW lives in another account it must be shared with
# this account through AWS RAM (and accepted) before the attachment works.

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count = local.attach_tgw ? 1 : 0

  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.this[0].id
  subnet_ids         = aws_subnet.private[*].id
  dns_support        = "enable"

  tags = { Name = "${var.name}-tgw-attachment" }
}

resource "aws_route" "private_tgw" {
  for_each = local.attach_tgw ? toset(var.transit_gateway_routes) : toset([])

  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = each.value
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# ── Optional internet access (commercial practice only) ────────────

resource "aws_internet_gateway" "this" {
  count  = local.create_igw ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  count = local.public_count

  vpc_id            = aws_vpc.this[0].id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr, 8, count.index)

  tags = { Name = "${var.name}-public-${local.azs[count.index]}", Tier = "public" }
}

resource "aws_route_table" "public" {
  count  = local.create_igw ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  tags   = { Name = "${var.name}-public-rt" }
}

resource "aws_route" "public_internet" {
  count                  = local.create_igw ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  count          = local.public_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_eip" "nat" {
  count  = local.create_nat ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  count         = local.create_nat ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.name}-nat" }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat" {
  count                  = local.create_nat ? 1 : 0
  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

# ── Interface VPC endpoints (reach AWS services without internet) ──

resource "aws_security_group" "endpoints" {
  count = length(var.interface_endpoints) > 0 ? 1 : 0

  name        = "${var.name}-vpc-endpoints"
  description = "HTTPS from the VPC to interface endpoints"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTPS from the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  tags = { Name = "${var.name}-vpc-endpoints" }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_endpoints)

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = local.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = { Name = "${var.name}-${each.value}" }
}

# ── VPC flow logs → CloudWatch (KMS-encrypted) ─────────────────────
# [ASSUMPTION A6] Flow logs for all traffic are required.

resource "aws_cloudwatch_log_group" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.kms_key_arn
}

data "aws_iam_policy_document" "flow_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name                 = "${var.name}-vpc-flow-logs"
  path                 = var.iam_role_path
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.flow_assume.json
}

data "aws_iam_policy_document" "flow_write" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name   = "write-flow-logs"
  role   = aws_iam_role.flow[0].id
  policy = data.aws_iam_policy_document.flow_write[0].json
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id          = local.vpc_id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow[0].arn
  log_destination = aws_cloudwatch_log_group.flow[0].arn
}
