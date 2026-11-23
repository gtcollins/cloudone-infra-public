# Module: `network`

Private networking for the CloudOne stack.

| Mode | Set | Creates |
|---|---|---|
| **Build a VPC** (default) | `create_vpc = true`, `cidr` | VPC, private subnets across `az_count` AZs, route table, default-SG lockdown |
| **Use CloudOne's VPC** | `create_vpc = false`, `existing_vpc_id`, `existing_private_subnet_ids` | Nothing network-level; only the optional extras below |

Optional extras (both modes unless noted):

| Feature | Inputs | Notes |
|---|---|---|
| Transit gateway attachment + routes | `transit_gateway_id`, `transit_gateway_routes` | Build mode only. A cross-account TGW must be RAM-shared first. |
| Interface VPC endpoints | `interface_endpoints = ["logs", "xray", "sts"]` | Reach AWS services without internet. Don't list `execute-api` (the api module owns it). |
| VPC flow logs → CloudWatch (KMS) | `enable_flow_logs`, `kms_key_arn`, `flow_log_retention_days` | Role gets `permissions_boundary_arn` / `iam_role_path` |
| Internet gateway / NAT | `enable_internet_gateway`, `enable_nat_gateway` | **Commercial practice only.** Build mode only. |

## Guards (plan fails with a clear message)
- build mode without a valid /16 `cidr`
- existing mode without `existing_vpc_id` / `existing_private_subnet_ids`
- NAT without an internet gateway
- a `0.0.0.0/0` TGW route together with NAT
- `execute-api` in `interface_endpoints`

## Outputs
`vpc_id`, `vpc_cidr`, `private_subnet_ids`, `public_subnet_ids`, `transit_gateway_attachment_id`, `interface_endpoint_ids`

## Example
```hcl
module "network" {
  source      = "../modules/network"
  name        = "cloudone-dev"
  cidr        = "10.10.0.0/16"
  kms_key_arn = module.kms.key_arn

  transit_gateway_id     = "tgw-0abc123"
  transit_gateway_routes = ["10.0.0.0/8"]
  interface_endpoints    = ["logs", "xray"]
}
```
