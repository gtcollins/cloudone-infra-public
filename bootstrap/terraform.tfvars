# ╔══════════════════════════════════════════════════════════════════════╗
# ║  Values for the one-time state bucket setup (run before any env).    ║
# ║  🛑 CHANGE ME = must replace   ⚠️ CONFIRM = check with CloudOne       ║
# ╚══════════════════════════════════════════════════════════════════════╝

aws_region        = "us-gov-west-1" # ⚠️ CONFIRM [C7]
use_fips_endpoint = true            # ⚠️ CONFIRM [C8]

# Same tags as envs/*/terraform.tfvars
required_tags = {
  Owner              = "TODO" # 🛑 CHANGE ME [C2]
  Mission            = "TODO" # 🛑 CHANGE ME [C2]
  CostCenter         = "TODO" # 🛑 CHANGE ME [C2]
  DataClassification = "TODO" # 🛑 CHANGE ME [C2]
}

access_log_bucket = null # ⚠️ CONFIRM [C16] central S3 access-log bucket, if CloudOne has one
