
#############################################
# modules/snowflake_integration/variables.tf
#############################################

variable "s3_bucket" {
  type        = string
  description = "S3 bucket containing raw data (full bucket name)"
}

variable "s3_prefix" {
  type        = string
  description = "S3 prefix/path within the bucket that Snowflake should access"
  default     = ""
}

variable "integration_name" {
  type        = string
  description = "Name for Snowflake storage integration"
  default     = "capstone_amazon_snowflake_s3_integration"
}

variable "iam_role_name" {
  type        = string
  description = "Name for the IAM role that Snowflake will assume"
  default     = "capstone_amazon_snowflake_s3_integration_role"
}

variable "snowflake_aws_account_id" {
  type        = string
  description = "Snowflake AWS account ID for initial permissive trust (region-specific)"
  default     = "898466741470"
}

variable "database_name" {
  description = "Snowflake database name"
  type        = string
}

variable "schema_name" {
  description = "Snowflake schema name"
  type        = string
}

