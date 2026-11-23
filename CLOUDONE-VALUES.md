# 📝 CloudOne Values Worksheet

> [!IMPORTANT]
> **Fill this in FIRST.** These are all the values the code needs from CloudOne. Ask them in one conversation, write each answer in the **✍️ Your answer** column, then copy it into the file and setting shown under **📁 Goes into**.
>
> **Everything else is already written and tested.** Once every row is answered and copied in, `./scripts/check-customization.sh` should print **✅ Nothing left to customize**.
>
> 🔒 **Don't commit the filled-in worksheet to a public place.** Account IDs and network ranges can be sensitive (CUI). Keep the filled copy in your work GitLab only.

**Legend:** 🛑 = the code can't deploy correctly without it · ⚠️ = a default exists, but confirm it · `(C#)` = section in [CUSTOMIZE.md](CUSTOMIZE.md)

---

## 1️⃣ Account & region

| # | ❓ Ask CloudOne | Format | Example | 📁 Goes into | ✍️ Your answer |
|:---:|---|---|---|---|---|
| V1 | 🛑 **AWS account ID for dev? For prod?** | 12 digits | `123456789012` | Bootstrap names the state bucket after it → `bucket` in `envs/*/backend.hcl` **(C1)** | dev: ________ prod: ________ |
| V2 | ⚠️ **Which region?** | region code | `us-gov-west-1` | `aws_region` in `envs/*/terraform.tfvars` + `bootstrap/terraform.tfvars`; `region` in `envs/*/backend.hcl` **(C7)** | |
| V3 | ⚠️ **Are FIPS endpoints required?** | yes / no | yes | `use_fips_endpoint` in the same 3 places **(C8)** | |
| V4 | ℹ️ **Impact level?** (informational) | IL2 / IL4 / IL5 | IL4 | No setting; affects which other answers apply | |

## 2️⃣ Tags

| # | ❓ Ask CloudOne | Format | Example | 📁 Goes into | ✍️ Your answer |
|:---:|---|---|---|---|---|
| V5 | 🛑 **Mandatory tag KEYS and their VALUES** | key = value list | `Owner = "jane.doe"`, `Program = "XYZ"` | `required_tags` in `envs/dev/terraform.tfvars`, `envs/prod/terraform.tfvars`, `bootstrap/terraform.tfvars` **(C2)** | |

## 3️⃣ IAM

| # | ❓ Ask CloudOne | Format | Example | 📁 Goes into | ✍️ Your answer |
|:---:|---|---|---|---|---|
| V6 | 🛑 **Permissions boundary policy ARN for new roles?** (or "none") | ARN | `arn:aws-us-gov:iam::123456789012:policy/CloudOne-Boundary` | `permissions_boundary_arn` in `envs/*/terraform.tfvars` **(C4)** | |
| V7 | ⚠️ **Required IAM role path or naming rule?** | path | `/cloudone/` | `iam_role_path` **(C13)** | |

## 4️⃣ Encryption

| # | ❓ Ask CloudOne | Format | Example | 📁 Goes into | ✍️ Your answer |
|:---:|---|---|---|---|---|
| V8 | ⚠️ **Do we use a shared KMS key, or create our own?** If shared: its ARN | ARN or "create" | `arn:aws-us-gov:kms:us-gov-west-1:123456789012:key/…` | `existing_kms_key_arn` (`null` = create one) **(C14)**. A shared key's policy must allow CloudWatch Logs. | |

## 5️⃣ Network

| # | ❓ Ask CloudOne | Format | Example | 📁 Goes into | ✍️ Your answer |
|:---:|---|---|---|---|---|
| V9 | ⚠️ **Is the VPC pre-built for us?** | yes / no | no | `create_vpc` (`false` if pre-built) **(C12)** | |
| V10 | 🛑 **If NOT pre-built:** CIDR for dev and prod | /16 each | `10.40.0.0/16` | `vpc_cidr` **(C5)** | dev: ________ prod: ________ |
| V11 | 🛑 **If pre-built:** VPC ID and private subnet IDs | IDs | `vpc-0abc…`, `["subnet-0aaa…","subnet-0bbb…"]` | `existing_vpc_id`, `existing_private_subnet_ids` **(C12)** | |
| V12 | ⚠️ **Transit gateway ID?** Is it shared to our account (RAM)? Which CIDRs route through it? | ID + CIDR list | `tgw-0abc…`, `["10.0.0.0/8"]` | `transit_gateway_id`, `transit_gateway_routes` **(C12)** | |
| V13 | 🛑 **Which user / VDI / bastion networks must reach the app?** | CIDR list | `["10.0.0.0/8"]` | `api_allowed_cidrs` **(C6)** | |
| V14 | ⚠️ **Which AWS services must we reach privately?** (VPC endpoints we create, or do they provide central ones?) | service list | `["logs","xray","sts"]` | `interface_endpoints` | |
| V15 | ⚠️ **Do they already collect VPC flow logs centrally?** | yes / no | no | `enable_flow_logs` (`false` if they do) **(C11)** | |

## 6️⃣ Authentication

| # | ❓ Ask CloudOne | Format | Example | 📁 Goes into | ✍️ Your answer |
|:---:|---|---|---|---|---|
| V16 | 🛑 **How must users / services authenticate to apps?** | one of: IAM · Cognito · CAC/IdP | CAC via IdP | `api_authorization` = `AWS_IAM`, `COGNITO_USER_POOLS` or `CUSTOM` **(C3)** | |
| V17 | **If Cognito:** user pool ARN(s) | ARN list | `["arn:aws-us-gov:cognito-idp:…:userpool/…"]` | `cognito_user_pool_arns` | |
| V18 | **If CAC/IdP:** the Lambda authorizer to use (do they provide one?) and the token header | ARN + header | `arn:aws-us-gov:lambda:…:function:authorizer`, `Authorization` | `custom_authorizer_lambda_arn`, `authorizer_identity_header` | |

## 7️⃣ Logging

| # | ❓ Ask CloudOne | Format | Example | 📁 Goes into | ✍️ Your answer |
|:---:|---|---|---|---|---|
| V19 | ⚠️ **Required log retention?** | days | `365` | `log_retention_days` **(C11)** | |
| V20 | ⚠️ **Are API access logs required? Does CloudOne manage the API Gateway CloudWatch role?** | yes / no ×2 | yes / no | `enable_api_access_logs`; `create_api_gateway_account_role` (`true` in **one** env only, if they don't manage it) **(C10)** | |
| V21 | ⚠️ **Central S3 access-log bucket name?** | bucket name | `cloudone-central-logs` | `access_log_bucket` in `bootstrap/terraform.tfvars` **(C16)** | |

## 8️⃣ Lambda

| # | ❓ Ask CloudOne | Format | Example | 📁 Goes into | ✍️ Your answer |
|:---:|---|---|---|---|---|
| V22 | ⚠️ **Is Lambda code signing required?** If so, the signing config ARN | ARN | `arn:aws-us-gov:lambda:…:code-signing-config:csc-…` | `lambda_code_signing_config_arn` **(C9)** | |
| V23 | ⚠️ **Any concurrency limits / reservations?** | number | `10` | `lambda_reserved_concurrency` (`-1` = none) **(C19)** | |

## 9️⃣ Process

| # | ❓ Ask CloudOne | Format | Example | 📁 Goes into | ✍️ Your answer |
|:---:|---|---|---|---|---|
| V24 | ⚠️ **Where must Terraform state live?** (our S3 bucket / theirs / GitLab-managed) | choice | our S3 bucket | `bootstrap/` + `envs/*/backend.hcl` **(C15)** | |
| V25 | ⚠️ **Approved CI images on our GitLab?** (Docker Hub blocked? Iron Bank?) | image names | `registry1.dso.mil/…/terraform:1.17` | `image:` lines in `.gitlab-ci.yml` **(C21)** | |
| V26 | ⚠️ **Is cross-region replication of state required (DR)?** | yes / no | no | **(C17)** | |
| V27 | ⚠️ **Is mTLS (client certificates) required on APIs?** | yes / no | no | **(C18)** | |

---

### ✅ After the meeting
1. Copy each answer into its file (all values live in `envs/<env>/terraform.tfvars`, `envs/<env>/backend.hcl`, `bootstrap/terraform.tfvars`).
2. Delete each `🛑 CHANGE ME` comment you've resolved.
3. Run `./scripts/check-customization.sh` until it prints ✅.
4. Follow **Part 4** of [CUSTOMIZE.md](CUSTOMIZE.md) to deploy.
