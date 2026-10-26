terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.95"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Day 4: the state file lives in S3, so every pipeline and person shares ONE state
  # (and a lock file stops two runs at the same time).
  # Bucket, key and region are passed by the pipeline:
  #   terraform init -backend-config="bucket=..." -backend-config="key=..." ...
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "user-management"
      ManagedBy = "terraform"
    }
  }
}
