# One-time setup: creates the S3 bucket that stores Terraform state for every
# CloudOne environment. This project itself uses LOCAL state (it can't store its
# state in a bucket that doesn't exist yet). Run it once per AWS account.

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
  }
}

provider "aws" {
  region            = var.aws_region
  use_fips_endpoint = var.use_fips_endpoint

  default_tags {
    tags = merge(var.required_tags, {
      Project   = "cloudone"
      Component = "terraform-state"
      ManagedBy = "terraform"
    })
  }
}

# [ASSUMPTION A1] AWS GovCloud (US)
variable "aws_region" {
  type    = string
  default = "us-gov-west-1"
}

# [ASSUMPTION A2] FIPS 140 validated endpoints
variable "use_fips_endpoint" {
  type    = bool
  default = true
}

# [ASSUMPTION A9] CloudOne's mandatory tags - set in bootstrap/terraform.tfvars
variable "required_tags" {
  type    = map(string)
  default = {}

  validation {
    condition     = !anytrue([for v in values(var.required_tags) : upper(v) == "TODO" || v == ""])
    error_message = "Fill in every required_tags value in bootstrap/terraform.tfvars (no TODO or empty values)."
  }
}

# [ASSUMPTION A14] CloudOne may provide a central S3 bucket for access logs.
variable "access_log_bucket" {
  description = "Existing bucket to receive state-bucket access logs (null = logging off)"
  type        = string
  default     = null
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Account root administers the key; IAM policies grant everything else.
data "aws_iam_policy_document" "state_key" {
  #checkov:skip=CKV_AWS_109:Standard KMS key policy - "*" in a key policy means this key only
  #checkov:skip=CKV_AWS_111:Standard KMS key policy - "*" in a key policy means this key only
  #checkov:skip=CKV_AWS_356:Standard KMS key policy - "*" in a key policy means this key only
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

# [ASSUMPTION A4] State is encrypted with a customer-managed key.
resource "aws_kms_key" "state" {
  description             = "cloudone: Terraform state bucket"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.state_key.json
}

resource "aws_kms_alias" "state" {
  name          = "alias/cloudone-tfstate"
  target_key_id = aws_kms_key.state.key_id
}

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV2_AWS_62:Event notifications have no use for a state bucket
  #checkov:skip=CKV_AWS_144:Cross-region replication is a CloudOne DR decision - see CUSTOMIZE.md
  #checkov:skip=CKV_AWS_18:Access logging is enabled by aws_s3_bucket_logging when access_log_bucket is set

  # Account ID makes the name globally unique and predictable for backend.tf.
  bucket = "cloudone-tfstate-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

# Versioning lets you recover a previous state if one is ever corrupted.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Keep old state versions for 90 days, then clean them up.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_logging" "state" {
  count = var.access_log_bucket == null ? 0 : 1

  bucket        = aws_s3_bucket.state.id
  target_bucket = var.access_log_bucket
  target_prefix = "tfstate/"
}

# Refuse any request that isn't over HTTPS.
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.state]
}

output "state_bucket" {
  description = "Put this name in envs/*/backend.hcl (bucket = ...)"
  value       = aws_s3_bucket.state.bucket
}

output "state_kms_key_arn" {
  value = aws_kms_key.state.arn
}
