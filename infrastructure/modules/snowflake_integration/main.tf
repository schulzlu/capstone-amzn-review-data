#############################################
# modules/snowflake_integration/main.tf
#############################################

# NOTE: This module expects aws and snowflake providers to be configured at root.

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.12.0"
    }
  }
}

# Build IAM policy that permits Snowflake to list & read the prefix
data "aws_iam_policy_document" "s3_read" {
  statement {
    sid       = "AllowListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation","s3:GetObjectVersion",
                "s3:GetObject"]
    resources = ["arn:aws:s3:::${var.s3_bucket}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.s3_prefix}*"]
    }
  }

  statement {
    sid       = "AllowGetObjects"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation","s3:GetObjectVersion",
                "s3:GetObject"]
    resources = ["arn:aws:s3:::${var.s3_bucket}/${var.s3_prefix}*"]
  }
}

resource "aws_iam_policy" "snowflake_s3_read" {
  name        = "snowflake-s3-read-policy"
  description = "Allow Snowflake to list and read objects under the raw prefix"
  policy      = data.aws_iam_policy_document.s3_read.json
}

resource "aws_iam_role" "snowflake_integration" {
  name = var.iam_role_name

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

resource "aws_iam_role_policy_attachment" "attach_read" {
  role       = aws_iam_role.snowflake_integration.name
  policy_arn = aws_iam_policy.snowflake_s3_read.arn
}

# Create Snowflake storage integration that references the IAM role
resource "snowflake_storage_integration" "capstone" {
  name                      = "S3_INTEGRATION"
  storage_provider          = "S3"
  enabled                   = true
  storage_aws_role_arn      = aws_iam_role.snowflake_integration.arn
  storage_allowed_locations = ["s3://${var.s3_bucket}/${var.s3_prefix}"]
}


// New ressources to auto-create stages and external table

# resource "snowflake_file_format" "parquet" {
#   name        = "PARQUET_FORMAT"
#   database    = var.database_name
#   schema      = var.schema_name
#   format_type = "PARQUET"
# }

# resource "snowflake_stage" "s3_parquet_stage" {
#   name        = "S3_PARQUET_STAGE"
#   database    = var.database_name
#   schema      = var.schema_name

#   url = "s3://${var.s3_bucket}/${var.s3_prefix}"

#   storage_integration = snowflake_storage_integration.capstone.name
#   file_format         = "FORMAT_NAME = ${snowflake_file_format.parquet.name}"
# }

# resource "snowflake_external_table" "raw_parquet" {
#   name     = "RAW_PARQUET_EXT"
#   database = var.database_name
#   schema   = var.schema_name

#   location    = "@${snowflake_stage.s3_parquet_stage.name}"
#   file_format = snowflake_file_format.parquet.name

#   column {
#     name = "value"
#     type = "VARIANT"
#     as   = "value"
#   }

#   depends_on = [
#     snowflake_stage.s3_parquet_stage,
#     snowflake_file_format.parquet
#   ]
# }
