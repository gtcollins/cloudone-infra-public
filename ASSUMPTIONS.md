# CloudOne assumptions register

> **Looking for what to change?** Start with **[CLOUDONE-VALUES.md](CLOUDONE-VALUES.md)** (collect answers) and **[CUSTOMIZE.md](CUSTOMIZE.md)** (apply them).
> This file explains the *reasoning* behind each guess.

This code was written **without** access to CloudOne's official environment rules.
Every rule below is a best guess based on common DoD / AWS GovCloud practice. Each guess is
tagged `[A#]` in the code and value files, so `grep -rn "A5"` finds everything a rule touches.

**Workflow:** confirm or correct each row with CloudOne, update the value files, then change
the status to ✅ Confirmed or ✏️ Changed.

| ID | Assumption | Setting(s) | Status |
|---|---|---|---|
| A1 | Resources run in **AWS GovCloud (US)**, `us-gov-west-1`. All ARNs are built from the partition, so the code also runs in commercial AWS. | `aws_region`, `region` (backend.hcl) | ❓ Unverified |
| A2 | **FIPS 140 endpoints** are mandatory | `use_fips_endpoint` | ❓ Unverified |
| A3 | **No direct internet.** CloudOne provides connectivity (e.g. a transit gateway). The internet gateway and NAT exist only for commercial practice. | `transit_gateway_id`, `transit_gateway_routes`, `enable_internet_gateway`, `enable_nat_gateway` | ❓ Unverified |
| A4 | **Customer-managed KMS keys** for logs, Lambda environment variables and state. Created per environment unless a shared key is given. | `existing_kms_key_arn` | ❓ Unverified |
| A5 | **No public endpoints.** API Gateway is `PRIVATE`, reachable only through an execute-api VPC endpoint. CloudFront isn't used (not in GovCloud); the Lambda serves the web page. | `api_endpoint_type`, `api_allowed_cidrs` | ❓ Unverified |
| A6 | **Logging:** VPC flow logs, X-Ray tracing, 365-day retention; API access logs optional (they need an account-wide role CloudOne may own) | `enable_flow_logs`, `log_retention_days`, `enable_api_access_logs`, `create_api_gateway_account_role` | ❓ Unverified |
| A7 | **Least-privilege network:** Lambda outbound limited to HTTPS inside the VPC; default security group stripped of rules (when we build the VPC) | `modules/api`, `modules/network` (code) | ❓ Unverified |
| A8 | **Authentication is required**, but the method is unknown. The placeholder is `NONE`, which must be changed. | `api_authorization` + `cognito_user_pool_arns` / `custom_authorizer_lambda_arn` | ⚠️ Must change |
| A9 | **Mandatory tags:** `Owner`, `Mission`, `CostCenter`, `DataClassification` (+ `Project`, `Environment`, `ManagedBy` added automatically) | `required_tags` | ❓ Unverified |
| A10 | **IAM permissions boundary + role path** required on every role | `permissions_boundary_arn`, `iam_role_path` | ❓ Unverified |
| A11 | **We build the VPC** with a CloudOne-assigned /16 (placeholders 10.10/10.20). CloudOne may pre-build it instead. | `create_vpc`, `vpc_cidr`, `existing_vpc_id`, `existing_private_subnet_ids` | ❓ Unverified |
| A12 | **State** lives in an S3 bucket in the same account, created by `bootstrap/` | `envs/*/backend.hcl`, `bootstrap/` | ❓ Unverified |
| A13 | **Code storage:** the final code lives in your work GitLab, not GitHub | `.gitlab-ci.yml` | ✅ Confirmed (you) |
| A14 | A **central access-log bucket** may exist for S3 access logs | `access_log_bucket` (bootstrap) | ❓ Unverified |
| A15 | **CI images** come from Docker Hub; DoD GitLab may require approved images (e.g. Iron Bank) | `image:` in `.gitlab-ci.yml` | ❓ Unverified |

## Questions to ask CloudOne

All of them, with formats and examples, are in **[CLOUDONE-VALUES.md](CLOUDONE-VALUES.md)** (V1–V27).
