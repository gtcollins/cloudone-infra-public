# cloudone-infra

Terraform for a serverless application on the **CloudOne** platform (AWS GovCloud).

## 🚀 START HERE: the 4-step workflow

> Everything you need is in this repo. Follow these steps in order.

| Step | Do this | Details |
|:---:|---|---|
| **1** | **Collect values from CloudOne.** Take the worksheet to your CloudOne contact and fill in the *✍️ Your answer* column. | [CLOUDONE-VALUES.md](CLOUDONE-VALUES.md) |
| **2** | **Move the repo to your work GitLab** (before adding any real values):<br>`git clone https://github.com/gtcollins/cloudone-infra.git`<br>`cd cloudone-infra`<br>`git remote set-url origin <your-gitlab-repo-url>`<br>`git push -u origin main` | [Moving to GitLab](#moving-to-your-work-gitlab) |
| **3** | **Copy the answers into the 5 value files**, deleting each `🛑 CHANGE ME` comment as you go, then run the checker until it prints ✅:<br>`./scripts/check-customization.sh` (Windows: `.\scripts\check-customization.ps1`) | [CUSTOMIZE.md](CUSTOMIZE.md) |
| **4** | **Deploy:** state bucket once, then dev, then prod:<br>`terraform -chdir=bootstrap init && terraform -chdir=bootstrap apply` → copy `state_bucket` into `envs/*/backend.hcl`<br>`./scripts/tf.sh dev init`<br>`./scripts/tf.sh dev plan -out=dev.tfplan` ← **read the plan**<br>`./scripts/tf.sh dev apply dev.tfplan` | [CUSTOMIZE.md → Part 4](CUSTOMIZE.md#-part-4-deploy) |

**The 5 value files** (the only files you edit): `envs/dev/terraform.tfvars` · `envs/dev/backend.hcl` · `envs/prod/terraform.tfvars` · `envs/prod/backend.hcl` · `bootstrap/terraform.tfvars`

> [!CAUTION]
> ## 🛑 NOT READY TO DEPLOY: customize first
> A **best-guess baseline**, written and tested without CloudOne's official rules.
> **All remaining work is filling in values**: no Terraform editing.
>
> | Step | Doc |
> |:---:|---|
> | **1** | 📝 **[CLOUDONE-VALUES.md](CLOUDONE-VALUES.md)**: one-page sheet of every value to get from CloudOne |
> | **2** | 🛠️ **[CUSTOMIZE.md](CUSTOMIZE.md)**: where each value goes: 6 mandatory 🛑, 15 to confirm ⚠️ |
> | **3** | ✅ `./scripts/check-customization.sh`: lists what's left (exit 0 = done) |
> | ref | [ASSUMPTIONS.md](ASSUMPTIONS.md) (why each guess) · [VERIFICATION.md](VERIFICATION.md) (what was tested) |

## Architecture

```
  CloudOne network / users ──► execute-api VPC endpoint (private DNS)
        (transit gateway)               │
                                        ▼
                     API Gateway REST API (PRIVATE) + authorizer
                                        │  "/" → web page, "/api/*" → JSON
                                        ▼
  ┌─────────── VPC (new or CloudOne's existing), private subnets ───────────┐
  │   Lambda (python3.13, X-Ray)  ── HTTPS to VPC only                      │
  │   optional: interface endpoints (logs, xray, sts…)                      │
  │   VPC flow logs → CloudWatch (KMS)                                      │
  └─────────────────────────────────────────────────────────────────────────┘
  KMS (own or shared) · required tags · permissions boundary on every role
```

## Layout

```
CLOUDONE-VALUES.md   📝 step 1: values to collect
CUSTOMIZE.md         🛠️ step 2: where each value goes
ASSUMPTIONS.md       why each guess was made
VERIFICATION.md      what was tested, what wasn't

envs/
  dev/  terraform.tfvars   ◄── YOUR VALUES (all dev settings)
        backend.hcl        ◄── YOUR VALUES (dev state location)
  prod/ terraform.tfvars   ◄── YOUR VALUES
        backend.hcl        ◄── YOUR VALUES
bootstrap/
  terraform.tfvars         ◄── YOUR VALUES (region + tags)
  main.tf                  one-time state bucket + KMS key

stack/              the Terraform root: wires modules together, holds NO values
modules/
  network/          VPC (new or existing), TGW, endpoints, flow logs   [README]
  kms/              per-environment key                                [README]
  api/              Lambda + private REST API + auth + logging         [README]
app/api/            Lambda code (handler.py) + web page (static/)
scripts/
  tf.sh / tf.ps1                    ./scripts/tf.sh <env> <command>
  check-customization.sh / .ps1     what's left to fill in
.github/workflows/  GitHub CI       .gitlab-ci.yml  GitLab CI (same checks)
```

**Why this layout:** the Terraform code (`stack/` + `modules/`) is identical for every environment and every repo. **Only the files marked ◄ differ.** Adding a `test` environment means copying `envs/dev` to `envs/test` and changing its values.

## Usage

```bash
# once per account: create the state bucket
terraform -chdir=bootstrap init
terraform -chdir=bootstrap apply          # copy state_bucket into envs/*/backend.hcl

# each environment
./scripts/tf.sh dev init
./scripts/tf.sh dev plan -out=dev.tfplan  # read the plan
./scripts/tf.sh dev apply dev.tfplan
./scripts/tf.sh dev output
```
Windows: `.\scripts\tf.ps1 dev plan` etc. Each environment keeps its own `.terraform-envs/<env>` cache, so switching between dev and prod needs no re-init.

## Moving to your work GitLab

```bash
git clone https://github.com/gtcollins/cloudone-infra.git
cd cloudone-infra
git remote set-url origin <your-gitlab-repo-url>
git push -u origin main
```
- `.gitlab-ci.yml` runs automatically. Swap its `image:` lines for approved images if Docker Hub is blocked (**C21**).
- Optional: delete `.github/` in the GitLab copy.
- Fill in real values **only in the GitLab copy**, never in the GitHub one.

## Practicing in a commercial AWS account

The code is partition-aware. In a copy of the tfvars set `aws_region = "us-east-1"`, `use_fips_endpoint = false`, `api_endpoint_type = "REGIONAL"`, `enable_internet_gateway = true`, and point `backend.hcl` at a bucket in that account.

## CI

GitHub (`.github/workflows/terraform-ci.yml`) and GitLab (`.gitlab-ci.yml`) both run, with no cloud credentials and nothing planned or applied:

| Job | Blocking? |
|---|---|
| `terraform fmt -check` + `validate` (bootstrap, stack) | ✅ yes |
| Checkov, using `envs/dev/terraform.tfvars` | report only |
| Customization status | report only: red until CUSTOMIZE.md is done |
