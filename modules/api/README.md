# Module: `api`

Python Lambda in private subnets behind an API Gateway **REST** API. The Lambda serves the web page at `/` and JSON at `/api/*`.

## What it creates
- Lambda (python3.13, X-Ray tracing, KMS-encrypted env vars, HTTPS-to-VPC-only security group)
- REST API, `PRIVATE` by default: an execute-api VPC endpoint + resource policy that only accepts calls through it
- Request validator, stage with throttling and metrics
- Log groups encrypted with `kms_key_arn`
- All IAM roles carry `permissions_boundary_arn` / `iam_role_path`

## Authentication (`authorization`)

| Value | Extra inputs | Use for |
|---|---|---|
| `NONE` | none | ⚠️ Testing only: no authentication |
| `AWS_IAM` (module default) | none | Service-to-service (SigV4). Browsers can't use it. |
| `COGNITO_USER_POOLS` | `cognito_user_pool_arns` | Users with Cognito JWTs |
| `CUSTOM` | `custom_authorizer_lambda_arn`, `authorizer_identity_header` | CloudOne IdP / CAC through a Lambda authorizer (TOKEN type) |

## Optional features

| Feature | Inputs |
|---|---|
| Access logs (JSON) + ERROR execution logs | `enable_access_logs = true` |
| Account-wide API Gateway logging role | `create_api_gateway_account_role = true`: **one environment per account only** |
| Lambda code signing | `code_signing_config_arn` (Enforce policies need a signed package) |
| Reserved concurrency | `reserved_concurrent_executions` (`-1` = unreserved) |
| Public API (practice) | `endpoint_type = "REGIONAL"` |
| Extra networks allowed in | `allowed_ingress_cidrs` |

## Guards
- `authorization` must be one of the four values
- `COGNITO_USER_POOLS` requires `cognito_user_pool_arns`
- `CUSTOM` requires `custom_authorizer_lambda_arn`

## Outputs
`invoke_url`, `rest_api_id`, `vpc_endpoint_id`, `function_name`, `authorization`, `access_log_group`, `lambda_security_group_id`
