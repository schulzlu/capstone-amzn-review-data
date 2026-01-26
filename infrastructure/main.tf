terraform {
  backend "s3" {
    bucket         = "iac-remote-state-amazon-data"
    key            = "terraform/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-locks-amazon-data"
    encrypt        = true
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.12.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

# ------------------------------------------------------------------
# Providers
# ------------------------------------------------------------------
provider "aws" {
  region = "eu-north-1"
}

provider "snowflake" {
  organization_name = var.org_name
  account_name      = var.account_name
  user              = var.snowflake_user
  password          = var.snowflake_password
  role              = var.snowflake_role
  warehouse         = var.snowflake_warehouse

  preview_features_enabled = [
    "snowflake_storage_integration_resource",
    "snowflake_stage_resource",
    "snowflake_file_format_resource",
    "snowflake_external_table_resource"
  ]
}

# ------------------------------------------------------------------
# Random suffix (dev-safe bucket creation)
# ------------------------------------------------------------------
resource "random_id" "rng" {
  keepers = {
    first = timestamp()
  }
  byte_length = 8
}

# ------------------------------------------------------------------
# S3 Bucket (data lake)
# ------------------------------------------------------------------
module "s3" {
  source = "./modules/s3"

  bucket_name   = "terraform-amazon-review-data-${random_id.rng.hex}"
  force_destroy = true # dev only

  prefixes = [
    "raw/",
    "scripts/",
    "tmp/",
    "flattened/"
  ]

  tags = {
    owner = "DATAENG"
    env   = "dev"
  }
}

# ------------------------------------------------------------------
# Snowflake (DB, schema, storage integration, stage)
# ------------------------------------------------------------------
module "snowflake" {
  source = "./modules/snowflake"

  providers = {
    snowflake = snowflake
  }

  org_name = var.org_name
  account_name      = var.account_name
  snowflake_user              = var.snowflake_user
  snowflake_password          = var.snowflake_password
  snowflake_role              = var.snowflake_role
  snowflake_warehouse         = var.snowflake_warehouse

  database_name = var.database_name
  schema_name   = var.schema_name

  # flattened_bucket = module.s3.bucket_id
  # flattened_prefix = "flattened"

  # snowflake_iam_role_arn = aws_iam_role.snowflake_s3_access.arn
}

module "snowflake_integration" {
  source = "./modules/snowflake_integration"

  # s3 inputs
  s3_bucket = module.s3.bucket_id
  s3_prefix = "flattened"

  database_name = var.database_name
  schema_name   = var.schema_name

  depends_on = [
    module.s3,
    module.snowflake
  ]
}

# ------------------------------------------------------------------
# IAM Role: Snowflake → S3
# ------------------------------------------------------------------

resource "aws_iam_role" "snowflake_integration" {
  name = "snowflake-s3-read"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.snowflake_aws_account_id}:root" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_iam_policy_document" "s3_read" {
  statement {
    sid       = "AllowListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation","s3:GetObjectVersion",
                "s3:GetObject"]
    resources = ["arn:aws:s3:::${module.s3.bucket_id}"]
  }

  statement {
    sid       = "AllowGetObjects"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation","s3:GetObjectVersion",
                "s3:GetObject"]
    resources = ["arn:aws:s3:::${module.s3.bucket_id}/flattened/*"]
  }
}

resource "aws_iam_policy" "snowflake_s3_read" {
  name        = "snowflake-s3-read"
  description = "Allow Snowflake to list and read objects under the raw prefix"
  policy      = data.aws_iam_policy_document.s3_read.json
}



# ------------------------------------------------------------------
# Glue Jobs
# ------------------------------------------------------------------
module "glue" {
  source = "./modules/glue"

  job_name_ingest = "raw-ingestion-job"
  job_name_flat   = "flatten-raw-data-job"

  script_bucket = module.s3.bucket_id
  raw_bucket    = module.s3.bucket_id
}
