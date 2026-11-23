# Customer-managed KMS key for one environment: CloudWatch Logs (Lambda, VPC
# flow logs) and Lambda environment variables.
# [ASSUMPTION A4] CloudOne requires customer-managed keys rather than AWS-managed ones.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  partition = data.aws_partition.current.partition
  account   = data.aws_caller_identity.current.account_id
  region    = data.aws_region.current.region
}

data "aws_iam_policy_document" "key" {
  #checkov:skip=CKV_AWS_109:Standard KMS key policy - "*" in a key policy means this key only
  #checkov:skip=CKV_AWS_111:Standard KMS key policy - "*" in a key policy means this key only
  #checkov:skip=CKV_AWS_356:Standard KMS key policy - "*" in a key policy means this key only
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account}:root"]
    }
  }

  statement {
    sid = "AllowCloudWatchLogs"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.${data.aws_partition.current.dns_suffix}"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${local.region}:${local.account}:*"]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "${var.name}: logs and Lambda environment variables"
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_in_days
  policy                  = data.aws_iam_policy_document.key.json
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}
