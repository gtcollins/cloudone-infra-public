# Python Lambda in private subnets behind an API Gateway REST API.
# [ASSUMPTION A3/A5] The API is PRIVATE: reachable only through an execute-api
# VPC endpoint inside the VPC (or networks CloudOne routes to it). HTTP APIs
# can't be private, so this uses a REST API. The same Lambda serves the web
# page at "/" (CloudFront isn't available in GovCloud).

data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  partition      = data.aws_partition.current.partition
  region         = data.aws_region.current.region
  private        = var.endpoint_type == "PRIVATE"
  use_authorizer = contains(["COGNITO_USER_POOLS", "CUSTOM"], var.authorization)
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/.build/${var.name}-api.zip"
}

# ── IAM ─────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name                 = "${var.name}-api-lambda"
  path                 = var.iam_role_path
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.assume_lambda.json
}

# CloudWatch Logs + the ENI permissions a VPC-attached Lambda needs.
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Decrypt the KMS-encrypted environment variables.
data "aws_iam_policy_document" "kms" {
  statement {
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "kms" {
  name   = "decrypt-env"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.kms.json
}

# ── Lambda ──────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name}-api"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

# [ASSUMPTION A7] No outbound internet: the Lambda may only talk HTTPS inside the VPC.
resource "aws_security_group" "lambda" {
  name        = "${var.name}-api-lambda"
  description = "CloudOne API Lambda - HTTPS to the VPC only"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS within the VPC (VPC endpoints, internal services)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.name}-api-lambda" }
}

resource "aws_lambda_function" "api" {
  #checkov:skip=CKV_AWS_116:Invoked synchronously by API Gateway - a dead-letter queue only applies to async invocations
  #checkov:skip=CKV_AWS_115:Configurable via reserved_concurrent_executions (C19); -1 = unreserved by default
  #checkov:skip=CKV_AWS_272:Configurable via code_signing_config_arn (C9); off until CloudOne provides a signing config
  function_name                  = "${var.name}-api"
  role                           = aws_iam_role.lambda.arn
  runtime                        = "python3.13"
  handler                        = "handler.handler"
  filename                       = data.archive_file.lambda.output_path
  source_code_hash               = data.archive_file.lambda.output_base64sha256
  memory_size                    = var.memory_size
  timeout                        = 10
  kms_key_arn                    = var.kms_key_arn
  reserved_concurrent_executions = var.reserved_concurrent_executions
  code_signing_config_arn        = var.code_signing_config_arn

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.vpc_access,
    aws_iam_role_policy.kms,
    aws_cloudwatch_log_group.lambda,
  ]
}

# ── Private access: execute-api VPC endpoint ────────────────────────

resource "aws_security_group" "endpoint" {
  count = local.private ? 1 : 0

  name        = "${var.name}-api-endpoint"
  description = "HTTPS into the execute-api VPC endpoint"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from allowed networks"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = concat([var.vpc_cidr], var.allowed_ingress_cidrs)
  }

  tags = { Name = "${var.name}-api-endpoint" }
}

resource "aws_vpc_endpoint" "execute_api" {
  count = local.private ? 1 : 0

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${local.region}.execute-api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoint[0].id]

  tags = { Name = "${var.name}-execute-api" }
}

# ── REST API ────────────────────────────────────────────────────────

resource "aws_api_gateway_rest_api" "this" {
  #checkov:skip=CKV_AWS_237:Replacing the API is rare; create-before-destroy would briefly run two APIs with the same name
  name = "${var.name}-api"

  endpoint_configuration {
    types            = [var.endpoint_type]
    vpc_endpoint_ids = local.private ? [aws_vpc_endpoint.execute_api[0].id] : null
  }
}

# Private APIs need a resource policy: allow invocation only via our endpoint.
data "aws_iam_policy_document" "api" {
  count = local.private ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.this.execution_arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {
    effect    = "Deny"
    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.this.execution_arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpce"
      values   = [aws_vpc_endpoint.execute_api[0].id]
    }
  }
}

resource "aws_api_gateway_rest_api_policy" "this" {
  count       = local.private ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.this.id
  policy      = data.aws_iam_policy_document.api[0].json
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

# ── Authentication [C3 / A8] ────────────────────────────────────────
# Set by var.authorization:
#   NONE                network access is the only control (NOT for CloudOne)
#   AWS_IAM             callers sign requests with AWS credentials (SigV4)
#   COGNITO_USER_POOLS  JWT from a Cognito user pool (cognito_user_pool_arns)
#   CUSTOM              Lambda authorizer for CloudOne's IdP / CAC
#                       (custom_authorizer_lambda_arn)

resource "aws_api_gateway_authorizer" "this" {
  count = local.use_authorizer ? 1 : 0

  name                             = "${var.name}-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.this.id
  type                             = var.authorization == "CUSTOM" ? "TOKEN" : "COGNITO_USER_POOLS"
  provider_arns                    = var.authorization == "COGNITO_USER_POOLS" ? var.cognito_user_pool_arns : null
  authorizer_uri                   = var.authorization == "CUSTOM" ? "arn:${local.partition}:apigateway:${local.region}:lambda:path/2015-03-31/functions/${var.custom_authorizer_lambda_arn}/invocations" : null
  identity_source                  = "method.request.header.${var.authorizer_identity_header}"
  authorizer_result_ttl_in_seconds = 300
}

resource "aws_lambda_permission" "authorizer" {
  count = var.authorization == "CUSTOM" ? 1 : 0

  statement_id  = "AllowApiGatewayAuthorizer-${var.name}"
  action        = "lambda:InvokeFunction"
  function_name = var.custom_authorizer_lambda_arn
  principal     = "apigateway.${data.aws_partition.current.dns_suffix}"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/authorizers/${aws_api_gateway_authorizer.this[0].id}"
}

resource "aws_api_gateway_request_validator" "this" {
  name                        = "${var.name}-validate-params"
  rest_api_id                 = aws_api_gateway_rest_api.this.id
  validate_request_parameters = true
  validate_request_body       = false
}

resource "aws_api_gateway_method" "root" {
  rest_api_id          = aws_api_gateway_rest_api.this.id
  resource_id          = aws_api_gateway_rest_api.this.root_resource_id
  http_method          = "ANY"
  authorization        = var.authorization
  authorizer_id        = local.use_authorizer ? aws_api_gateway_authorizer.this[0].id : null
  request_validator_id = aws_api_gateway_request_validator.this.id
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id          = aws_api_gateway_rest_api.this.id
  resource_id          = aws_api_gateway_resource.proxy.id
  http_method          = "ANY"
  authorization        = var.authorization
  authorizer_id        = local.use_authorizer ? aws_api_gateway_authorizer.this[0].id : null
  request_validator_id = aws_api_gateway_request_validator.this.id
}

resource "aws_api_gateway_integration" "root" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_rest_api.this.root_resource_id
  http_method             = aws_api_gateway_method.root.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Redeploy whenever routes, auth, integrations or the resource policy change.
  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.root,
      aws_api_gateway_method.proxy,
      aws_api_gateway_integration.root.id,
      aws_api_gateway_integration.proxy.id,
      local.private ? data.aws_iam_policy_document.api[0].json : "",
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.root,
    aws_api_gateway_integration.proxy,
    aws_api_gateway_rest_api_policy.this,
  ]
}

# ── Access logging [C10 / A6] ───────────────────────────────────────
# API Gateway writes logs using ONE account-wide role per region
# (aws_api_gateway_account). Set create_api_gateway_account_role = true in
# exactly one environment per account, and only if CloudOne doesn't manage it.

resource "aws_cloudwatch_log_group" "access" {
  count = var.enable_access_logs ? 1 : 0

  name              = "/aws/apigateway/${var.name}-api/access"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

data "aws_iam_policy_document" "apigw_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "apigw_cloudwatch" {
  count = var.create_api_gateway_account_role ? 1 : 0

  name                 = "${var.name}-apigw-cloudwatch"
  path                 = var.iam_role_path
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.apigw_assume.json
}

resource "aws_iam_role_policy_attachment" "apigw_cloudwatch" {
  count = var.create_api_gateway_account_role ? 1 : 0

  role       = aws_iam_role.apigw_cloudwatch[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  count = var.create_api_gateway_account_role ? 1 : 0

  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch[0].arn

  depends_on = [aws_iam_role_policy_attachment.apigw_cloudwatch]
}

resource "aws_api_gateway_stage" "this" {
  #checkov:skip=CKV_AWS_120:Response caching adds cost and isn't needed for this API
  #checkov:skip=CKV2_AWS_51:mTLS needs a custom domain + truststore - tracked as C18 in CUSTOMIZE.md
  rest_api_id          = aws_api_gateway_rest_api.this.id
  deployment_id        = aws_api_gateway_deployment.this.id
  stage_name           = var.stage_name
  xray_tracing_enabled = true

  dynamic "access_log_settings" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.access[0].arn
      format = jsonencode({
        requestId       = "$context.requestId"
        sourceIp        = "$context.identity.sourceIp"
        requestTime     = "$context.requestTime"
        httpMethod      = "$context.httpMethod"
        resourcePath    = "$context.resourcePath"
        status          = "$context.status"
        responseLength  = "$context.responseLength"
        userAgent       = "$context.identity.userAgent"
        authorizerError = "$context.authorizer.error"
      })
    }
  }

  depends_on = [aws_api_gateway_account.this]
}

resource "aws_api_gateway_method_settings" "all" {
  #checkov:skip=CKV_AWS_225:Response caching adds cost and isn't needed for this API
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = var.enable_access_logs ? "ERROR" : "OFF"
    throttling_burst_limit = var.throttle_burst
    throttling_rate_limit  = var.throttle_rate
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowRestApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.${data.aws_partition.current.dns_suffix}"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}
