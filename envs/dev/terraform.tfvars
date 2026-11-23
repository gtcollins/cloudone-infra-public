# ╔══════════════════════════════════════════════════════════════════════╗
# ║  🛑  STOP - THIS FILE NEEDS YOUR CLOUDONE VALUES BEFORE DEPLOYING  🛑  ║
# ║                                                                      ║
# ║  🛑 CHANGE ME  = placeholder. MUST be replaced.                       ║
# ║  ⚠️ CONFIRM    = best guess. Check with CloudOne, change if wrong.     ║
# ║  (when ...)    = only matters in that situation.                     ║
# ║                                                                      ║
# ║  Collect the answers first:  CLOUDONE-VALUES.md   (one-page sheet)   ║
# ║  Step-by-step guide:         CUSTOMIZE.md                            ║
# ║  What's left:                ./scripts/check-customization.sh        ║
# ╚══════════════════════════════════════════════════════════════════════╝

# ── 1. Environment & region ─────────────────────────────────────────
environment       = "dev"
aws_region        = "us-gov-west-1" # ⚠️ CONFIRM [C7] region CloudOne assigned
use_fips_endpoint = true            # ⚠️ CONFIRM [C8] FIPS endpoints required?

# ── 2. Tags [C2] ────────────────────────────────────────────────────
# Replace keys AND values with CloudOne's mandatory tags.
# `plan` refuses to run while any value is "TODO".
required_tags = {
  Owner              = "TODO" # 🛑 CHANGE ME [C2]
  Mission            = "TODO" # 🛑 CHANGE ME [C2]
  CostCenter         = "TODO" # 🛑 CHANGE ME [C2]
  DataClassification = "TODO" # 🛑 CHANGE ME [C2]
}

# ── 3. IAM ──────────────────────────────────────────────────────────
# Example: "arn:aws-us-gov:iam::123456789012:policy/CloudOne-Boundary"
permissions_boundary_arn = null # 🛑 CHANGE ME [C4] (or confirm none is required)
iam_role_path            = "/"  # ⚠️ CONFIRM [C13] e.g. "/cloudone/"

# ── 4. Encryption ───────────────────────────────────────────────────
existing_kms_key_arn     = null # ⚠️ CONFIRM [C14] shared key ARN, or null to create one
kms_deletion_window_days = 7    # (when creating a key) 7-30 days

# ── 5. Network ──────────────────────────────────────────────────────
create_vpc = true # ⚠️ CONFIRM [C12] false if CloudOne pre-builds the VPC

#   (when create_vpc = true)
vpc_cidr = "10.10.0.0/16" # 🛑 CHANGE ME [C5] CIDR CloudOne assigns (a /16)
az_count = 2

#   (when create_vpc = false)  e.g. "vpc-0abc..." and ["subnet-0aaa...", "subnet-0bbb..."]
existing_vpc_id             = null
existing_private_subnet_ids = []

#   (when CloudOne gives you a transit gateway; create_vpc = true)
transit_gateway_id     = null # ⚠️ CONFIRM [C12] e.g. "tgw-0abc..."
transit_gateway_routes = []   # ⚠️ CONFIRM [C12] e.g. ["10.0.0.0/8"] or ["0.0.0.0/0"]

#   AWS services reached without internet, e.g. ["logs", "xray", "sts"]
interface_endpoints = []

enable_flow_logs        = true  # ⚠️ CONFIRM [C11] false if CloudOne already collects them
enable_internet_gateway = false # keep false in CloudOne (practice only)
enable_nat_gateway      = false # keep false in CloudOne (practice only)

# ── 6. API ──────────────────────────────────────────────────────────
api_endpoint_type = "PRIVATE" # ⚠️ CONFIRM [A5]
api_allowed_cidrs = []        # 🛑 CHANGE ME [C6] user/VDI networks that must reach the API

# NONE | AWS_IAM | COGNITO_USER_POOLS | CUSTOM.  NONE = no authentication!
api_authorization = "NONE" # 🛑 CHANGE ME [C3]

#   (when api_authorization = "COGNITO_USER_POOLS")
cognito_user_pool_arns = []
#   (when api_authorization = "CUSTOM")  Lambda authorizer for CloudOne's IdP / CAC
custom_authorizer_lambda_arn = null
#   (when COGNITO or CUSTOM)  header that carries the token
authorizer_identity_header = "Authorization"

enable_api_access_logs          = false # ⚠️ CONFIRM [C10]
create_api_gateway_account_role = false # ⚠️ CONFIRM [C10] true in ONE env per account, if CloudOne doesn't manage it

# ── 7. Lambda ───────────────────────────────────────────────────────
lambda_memory_mb               = 128
lambda_reserved_concurrency    = -1   # ⚠️ CONFIRM [C19] -1 = unreserved
lambda_code_signing_config_arn = null # ⚠️ CONFIRM [C9] signing config ARN if required

# ── 8. Logging ──────────────────────────────────────────────────────
log_retention_days = 365 # ⚠️ CONFIRM [C11] required retention period
