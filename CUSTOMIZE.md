# 🛠️ CUSTOMIZE ME: CloudOne Deployment Checklist

> [!CAUTION]
> ## 🛑 This code is a BEST-GUESS BASELINE. It is NOT ready to deploy.
> It was written **without** CloudOne's official environment rules.
> **Work through every 🛑 item below before running `apply`.**
> Placeholders are designed to make `init` / `plan` **fail** until replaced, so nothing deploys with guessed values by accident.

> [!TIP]
> ### ✨ You only edit VALUES, never Terraform code
> Every customization is a setting in one of these **5 files**:
>
> | File | What's in it |
> |---|---|
> | **`envs/dev/terraform.tfvars`** | All dev settings |
> | **`envs/dev/backend.hcl`** | Where dev state is stored |
> | **`envs/prod/terraform.tfvars`** | All prod settings |
> | **`envs/prod/backend.hcl`** | Where prod state is stored |
> | **`bootstrap/terraform.tfvars`** | Region + tags for the one-time state bucket |
>
> 📝 **Collect the answers first with [CLOUDONE-VALUES.md](CLOUDONE-VALUES.md)**, a one-page sheet to fill in with CloudOne.

---

## 📋 How to use this file

1. **See what's left:**
   ```bash
   ./scripts/check-customization.sh        # macOS / Linux / Git Bash
   .\scripts\check-customization.ps1       # Windows PowerShell
   ```
   It prints every line still marked `🛑 CHANGE ME`, with file and line number.
2. **Work top to bottom**, ticking each box.
3. **After replacing a value, delete its `🛑 CHANGE ME` comment** so the checker stops reporting it.
4. When the checker prints **✅ Nothing left to customize**, go to **Part 4**.

### Markers in the files

| Marker | Meaning | What you do |
|---|---|---|
| **`🛑 CHANGE ME`** | **Placeholder. Deploy fails or is unsafe until replaced.** | **Replace it. Mandatory.** |
| **`⚠️ CONFIRM`** | A best guess that works as written | Check with CloudOne; change if wrong |
| **`(when …)`** | Only used in that situation | Fill in only if it applies |
| **`[C#]`** | Item in **this** checklist | Read that item below |
| **`[A#]`** | Row in [ASSUMPTIONS.md](ASSUMPTIONS.md) | The reasoning behind the guess |

### At a glance

| Priority | Items | If you skip them |
|---|:---:|---|
| 🛑 **MUST CHANGE** | **C1 – C6** | `init`/`plan` fails, deployment fails, **or the API has no authentication** |
| ⚠️ **CONFIRM** | **C7 – C21** | Probably works, but may break CloudOne policy |
| 💡 **GOOD TO KNOW** | G1 – G7 | Surprises after deployment |

---

## 🛑 PART 1: MUST CHANGE (6 items, all mandatory)

### 🛑 C1: State bucket name
- [ ] **`envs/dev/backend.hcl`** · [ ] **`envs/prod/backend.hcl`**

| | |
|---|---|
| **Setting** | `bucket` |
| **Placeholder** | `"cloudone-tfstate-REPLACE_WITH_ACCOUNT_ID"` |
| **Replace with** | **The `state_bucket` output printed by bootstrap** (Part 4, step 1) |
| **Example** | `"cloudone-tfstate-123456789012"` |
| **If skipped** | ❌ `init` fails (intentional) |

> If CloudOne provides its own state backend, replace the contents of `backend.hcl` with their settings and skip `bootstrap/` **(C15)**.

### 🛑 C2: Mandatory tags
- [ ] **`envs/dev/terraform.tfvars`** · [ ] **`envs/prod/terraform.tfvars`** · [ ] **`bootstrap/terraform.tfvars`**

| | |
|---|---|
| **Setting** | `required_tags` |
| **Placeholder** | `Owner`, `Mission`, `CostCenter`, `DataClassification`, all `"TODO"` |
| **Replace with** | **CloudOne's real tag keys AND values.** Rename, add or remove keys freely. |
| **Example** | `required_tags = { Owner = "jane.doe", Program = "XYZ", CostCenter = "1234" }` |
| **If skipped** | ❌ `plan` stops with *"Fill in every required_tags value"* (intentional) |

### 🛑 C3: API authentication ⚠️ **SECURITY**
- [ ] **dev** · [ ] **prod**

| | |
|---|---|
| **Setting** | `api_authorization` (+ the `(when …)` settings below it) |
| **Placeholder** | `"NONE"`: **anyone who can reach the private endpoint can call the API** |
| **Replace with** | One of: |
| | • **`"AWS_IAM"`**: callers sign requests with AWS credentials (service-to-service) |
| | • **`"COGNITO_USER_POOLS"`**: also set `cognito_user_pool_arns` |
| | • **`"CUSTOM"`**: Lambda authorizer for CloudOne's IdP / CAC. Also set `custom_authorizer_lambda_arn` (+ `authorizer_identity_header` if the token isn't in `Authorization`) |
| **If skipped** | ⚠️ Deploys, **but with no authentication.** Checkov reports `CKV_AWS_59`. |
| **Guards** | `plan` refuses `COGNITO_USER_POOLS` without pool ARNs and `CUSTOM` without an authorizer ARN |

### 🛑 C4: IAM permissions boundary
- [ ] **dev** · [ ] **prod**

| | |
|---|---|
| **Setting** | `permissions_boundary_arn` |
| **Placeholder** | `null` (no boundary) |
| **Replace with** | **The boundary policy ARN from CloudOne**, applied to **every** role this code creates |
| **Example** | `"arn:aws-us-gov:iam::123456789012:policy/CloudOne-Boundary"` |
| **If skipped** | ❌ Many DoD accounts **deny role creation** without it, so `apply` fails part-way |

> If CloudOne confirms no boundary is needed, leave `null` and just delete the `🛑 CHANGE ME` comment.

### 🛑 C5: Network: VPC CIDR *(or the existing VPC)*
- [ ] **dev** · [ ] **prod**

| | |
|---|---|
| **If CloudOne does NOT pre-build the VPC** | Set **`vpc_cidr`** to the /16 they assign. Placeholders: dev `10.10.0.0/16`, prod `10.20.0.0/16` |
| **If CloudOne DOES pre-build it** | Set **`create_vpc = false`**, **`existing_vpc_id`**, **`existing_private_subnet_ids`**. Then `vpc_cidr` is ignored; set it to `null` and delete its `🛑` comment. |
| **If skipped** | ⚠️ May collide with other networks, so routing breaks |
| **Guards** | `plan` refuses `create_vpc = true` without a valid /16, or `create_vpc = false` without IDs |

### 🛑 C6: Who may reach the API
- [ ] **dev** · [ ] **prod**

| | |
|---|---|
| **Setting** | `api_allowed_cidrs` |
| **Placeholder** | `[]`: only traffic from inside the VPC |
| **Replace with** | **The user / VDI / bastion networks that must open the app** |
| **Example** | `["10.0.0.0/8"]` |
| **If skipped** | ⚠️ Nobody outside the VPC can reach the app |

---

## ⚠️ PART 2: CONFIRM WITH CLOUDONE (15 items)

All of these **work as written**. Change the setting if CloudOne's answer differs. Unless noted, settings are in `envs/<env>/terraform.tfvars`.

| ☑️ | ID | 🔍 Current guess | ✏️ Setting to change |
|:---:|:---:|---|---|
| ☐ | **C7** | Region **`us-gov-west-1`** | `aws_region` (tfvars ×2 + `bootstrap/terraform.tfvars`) and `region` (`backend.hcl` ×2) |
| ☐ | **C8** | **FIPS endpoints** required | `use_fips_endpoint` (same 5 places) |
| ☐ | **C9** | **No Lambda code signing** | `lambda_code_signing_config_arn`. ⚠️ With an *Enforce* policy the package must be signed first (S3 + AWS Signer job). |
| ☐ | **C10** | **API access logs off** | `enable_api_access_logs = true`. If CloudOne doesn't manage the API Gateway logging role, also set `create_api_gateway_account_role = true` in **one** environment per account. |
| ☐ | **C11** | Logs kept **365 days**; **VPC flow logs on** | `log_retention_days`, `enable_flow_logs` |
| ☐ | **C12** | **We build the VPC; no transit gateway** | `create_vpc`, `existing_vpc_id`, `existing_private_subnet_ids`, `transit_gateway_id`, `transit_gateway_routes` |
| ☐ | **C13** | IAM role path **`/`** | `iam_role_path` |
| ☐ | **C14** | Each environment **creates its own KMS key** | `existing_kms_key_arn` (a shared key's policy must allow CloudWatch Logs) |
| ☐ | **C15** | State in **our S3 bucket** (made by `bootstrap/`) | `envs/*/backend.hcl` |
| ☐ | **C16** | **No access logging** on the state bucket | `access_log_bucket` in `bootstrap/terraform.tfvars` |
| ☐ | **C17** | **No cross-region replication** of state | Add `aws_s3_bucket_replication_configuration` in `bootstrap/main.tf` (the only item needing code) |
| ☐ | **C18** | **No mTLS** on the API | Needs a custom domain + truststore; add only if required |
| ☐ | **C19** | **No reserved concurrency** | `lambda_reserved_concurrency` |
| ☐ | **C20** | Code may live in **GitHub** | Move to your work GitLab (see README → *Moving to GitLab*) |
| ☐ | **C21** | CI images come from **Docker Hub** | `image:` lines in `.gitlab-ci.yml` (Iron Bank / internal registry) |

---

## 💡 PART 3: GOOD TO KNOW

| | Gotcha | Why it matters |
|---|---|---|
| **G1** | **`invoke_url` only works from inside the VPC** (or networks routed in) | The API is `PRIVATE`; opening it from a laptop off-network fails. That's expected. |
| **G2** | **Private DNS on the `execute-api` endpoint affects the whole VPC** | Anything in this VPC calling *public* API Gateway APIs will resolve to the endpoint and fail. |
| **G3** | **`AWS_IAM` auth blocks the browser page** | Browsers can't sign requests. For people using a browser, use `CUSTOM` (IdP/CAC) or `COGNITO_USER_POOLS`. |
| **G4** | **X-Ray in a VPC with no internet** | Add `"xray"` to `interface_endpoints` if trace data doesn't arrive. |
| **G5** | **`create_api_gateway_account_role` is account-wide** | Setting it `true` in both dev and prod (same account) makes them overwrite each other. |
| **G6** | **Transit gateway in another account** | It must be shared via AWS RAM and accepted before the attachment can be created. |
| **G7** | **Security scan** | With your values, open Checkov findings clear once **C3** and **C10** are set. See [VERIFICATION.md](VERIFICATION.md). |

---

## ✅ PART 4: Deploy

- [ ] `./scripts/check-customization.sh` prints **✅ Nothing left to customize**
- [ ] Every row in [ASSUMPTIONS.md](ASSUMPTIONS.md) is ✅ Confirmed or ✏️ Changed
- [ ] **1. State bucket (once per account):**
  ```bash
  terraform -chdir=bootstrap init && terraform -chdir=bootstrap apply
  ```
  Copy the `state_bucket` output into **`envs/dev/backend.hcl`** and **`envs/prod/backend.hcl`**.
- [ ] **2. Dev:**
  ```bash
  ./scripts/tf.sh dev init
  ./scripts/tf.sh dev plan -out=dev.tfplan      # READ THE PLAN
  ./scripts/tf.sh dev apply dev.tfplan
  ```
- [ ] **3. Test** from a machine on an allowed network: open the `invoke_url` output.
- [ ] **4. Prod:** same commands with `prod`.

> [!TIP]
> Windows: use `.\scripts\tf.ps1` instead of `./scripts/tf.sh`, same arguments.
