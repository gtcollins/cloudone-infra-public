terraform {
  # 1.10+ for S3 native state locking (use_lockfile)
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.8"
    }
  }
}

provider "aws" {
  region            = var.aws_region
  use_fips_endpoint = var.use_fips_endpoint

  default_tags {
    tags = merge(var.required_tags, {
      Project     = "cloudone"
      Environment = var.environment
      ManagedBy   = "terraform"
    })
  }
}
