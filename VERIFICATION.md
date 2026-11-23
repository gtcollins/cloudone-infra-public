# ✅ Verification Report

**Date:** 2026-11-22 · **Terraform** 1.17.2 · **AWS provider** 6.73.0 · **archive** 2.8.1 · **Checkov** 3.4.6

> [!IMPORTANT]
> **Verified:** the code is valid, every option combination produces a correct plan that AWS accepts, and every guard blocks bad input.
> **NOT verified:** that it matches CloudOne's actual rules, or a real deployment in GovCloud. Finish **[CUSTOMIZE.md](CUSTOMIZE.md)** first.

All plans ran **read-only** against a commercial AWS account (`us-east-1`, FIPS off, local state). Nothing was created.

---

## 1. Scenario plans: every feature combination

| # | Scenario | Key settings | Result | Checked inside the plan |
|:---:|---|---|:---:|---|
| S1 | **CloudOne default** | new VPC, PRIVATE API, auth `NONE`, flow logs | ✅ **34** resources | n/a |
| S2 | **Everything on** | `AWS_IAM`, access logs + account role, reserved concurrency, code signing, shared KMS key, TGW + 2 routes, 3 interface endpoints, permissions boundary, role path `/cloudone/` | ✅ **43** | TGW attachment 1 ✔ · TGW routes 2 ✔ · endpoints 3 ✔ · logging role 1 ✔ · access log group 1 ✔ · **no** KMS key created (shared key used) ✔ · **all 3 IAM roles carry the boundary + path** ✔ |
| S3 | **Cognito auth** | `COGNITO_USER_POOLS` + pool ARN | ✅ **35** | authorizer created ✔ |
| S4 | **Custom authorizer** (IdP/CAC) | `CUSTOM` + Lambda ARN + custom header | ✅ **36** | authorizer 1 ✔ · authorizer invoke permission 1 ✔ |
| S5 | **CloudOne's existing VPC** | `create_vpc = false` + a real VPC and 2 real subnets, flow logs off, 1 endpoint | ✅ **25** | **no** VPC/subnets/flow logs created ✔ · Lambda + endpoints placed in the existing VPC ✔ |
| S6 | **Commercial practice** | internet gateway + NAT + REGIONAL API | ✅ **41** | n/a |
| B | **Bootstrap** (state bucket + KMS key) | | ✅ **9** | n/a |

## 2. Guards: bad input is refused with a clear message

| # | Bad input | Result | Message |
|:---:|---|:---:|---|
| G1 | Cognito auth without pool ARNs | ✅ blocked | *cognito_user_pool_arns is required…* |
| G2 | Custom auth without authorizer ARN | ✅ blocked | *custom_authorizer_lambda_arn is required…* |
| G3 | Existing-VPC mode without IDs | ✅ blocked | *existing_vpc_id is required…* |
| G4 | TGW `0.0.0.0/0` route + NAT | ✅ blocked | *…conflicts with enable_nat_gateway…* |
| G5 | `execute-api` in `interface_endpoints` | ✅ blocked | *Don't list execute-api here…* |
| G6 | New VPC without a CIDR | ✅ blocked | *cidr must be a valid /16…* |
| G7 | Unknown auth type | ✅ blocked | *authorization must be NONE, AWS_IAM…* |
| G8 | `TODO` tags in `envs/dev/terraform.tfvars` | ✅ blocked | *Fill in every required_tags value…* |
| G9 | `TODO` tags in `bootstrap/terraform.tfvars` | ✅ blocked | same |
| G10 | `REPLACE_WITH_ACCOUNT_ID` in `backend.hcl` | ✅ by design | `init` can't succeed until replaced |

## 3. Tooling

| Check | Result |
|---|:---:|
| `terraform fmt -check -recursive` | ✅ |
| `validate`: `bootstrap`, `stack` | ✅ |
| Provider lock files: linux / windows / darwin (amd64 + arm64) | ✅ |
| `scripts/tf.ps1`: `dev init`, `dev validate`, unknown env rejected | ✅ |
| `scripts/tf.sh` (Git Bash): `prod init`, `prod validate`, usage message | ✅ |
| Separate `.terraform-envs/<env>` cache per environment | ✅ |
| `check-customization.sh` and `.ps1` agree: **22 lines** to fill in | ✅ |
| Lambda handler (`/` → 200, `/api/hello` → 200, unknown → 404) | ✅ |
| Secret scan of the commits | ✅ none |

## 4. Security scan (Checkov)

| Scan | Passed | Open | Skipped |
|---|:---:|:---:|:---:|
| Code defaults | 183 | 1 | 17 |
| **With `envs/dev/terraform.tfvars`** (what would deploy) | **183** | **3** | 17 |

**The 3 open findings are all VALUES, not code:**

| Finding | Clears when you set |
|---|---|
| `CKV_AWS_59` ×2: API open to back-end | `api_authorization` ≠ `NONE` **(C3)** |
| `CKV2_AWS_4`: API logging level | `enable_api_access_logs = true` **(C10)** |

Every skip has its reason written next to it in the code (`#checkov:skip=ID:reason`). Summary:

| Skipped | Why |
|---|---|
| `CKV_AWS_109/111/356` (KMS key policies) | Standard key policy: `"*"` in a key policy means *this key* |
| `CKV_AWS_116` Lambda DLQ | Synchronous invocation; DLQs only apply to async |
| `CKV_AWS_115` / `CKV_AWS_272` | Configurable: `lambda_reserved_concurrency` (C19) / `lambda_code_signing_config_arn` (C9) |
| `CKV_AWS_120/225` API caching | Cost; not needed |
| `CKV_AWS_237` | Would briefly run two APIs with the same name |
| `CKV2_AWS_51` mTLS | Needs custom domain + truststore (C18) |
| `CKV_AWS_394` AZ pinning | Only the first `az_count` AZs are used |
| `CKV2_AWS_62`, `CKV_AWS_144`, `CKV_AWS_18` (state bucket) | Not useful / DR decision (C17) / enabled via `access_log_bucket` (C16) |

## 5. NOT verified ❌

| Gap | How to close it |
|---|---|
| Deployment in **GovCloud** (FIPS endpoints, partition ARNs at apply time) | `plan` + `apply` dev in the CloudOne account |
| **CloudOne compliance** | CLOUDONE-VALUES.md + ASSUMPTIONS.md with CloudOne |
| **`apply`** of any scenario | Apply dev first after customizing |
| **End-to-end request** through the private endpoint and authorizer | Open `invoke_url` from an allowed network after apply |
| **GitLab CI** on your instance (images, runners) | Push to GitLab; adjust `image:` lines (C21) |
| **Code signing with Enforce** (needs a signed package) | Only if C9 applies |

## 6. Re-run the checks yourself

```bash
terraform fmt -check -recursive
for d in bootstrap stack; do terraform -chdir=$d init -backend=false && terraform -chdir=$d validate; done
./scripts/check-customization.sh
pip install checkov==3.4.6 && checkov -d . --framework terraform --compact --var-file envs/dev/terraform.tfvars
```
On Windows, set `PYTHONUTF8=1` before Checkov.
