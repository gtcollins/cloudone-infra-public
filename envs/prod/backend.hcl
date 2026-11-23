# ╔══════════════════════════════════════════════════════════════════════╗
# ║  Where Terraform stores the PROD state.
# ║  Used by:  ./scripts/tf.sh prod init
# ║  🛑 CHANGE ME [C1]: bucket = the state_bucket output of bootstrap/
# ╚══════════════════════════════════════════════════════════════════════╝
bucket            = "cloudone-tfstate-REPLACE_WITH_ACCOUNT_ID" # 🛑 CHANGE ME [C1]
key               = "cloudone/prod/terraform.tfstate"
region            = "us-gov-west-1" # ⚠️ CONFIRM [C7] same region as the bucket
use_fips_endpoint = true            # ⚠️ CONFIRM [C8]
encrypt           = true
use_lockfile      = true
