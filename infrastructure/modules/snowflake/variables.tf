variable "project_prefix" {
  type        = string
  description = "Prefix used for naming Snowflake database/schema when defaults are used."
  default     = "capstone_amazon"
}

variable "org_name" {
  type        = string
  description = "The Snowflake organization name. The 'snowflake_account' variable is deprecated."
  # It is best practice to provide this value in a .tfvars file or as an environment variable.
}

variable "account_name" {
  type        = string
  description = "The Snowflake account name within the organization. The 'snowflake_account' variable is deprecated."
  # It is best practice to provide this value in a .tfvars file or as an environment variable.
}

variable "snowflake_user" {
  type        = string
  description = "Snowflake user used by Terraform. The 'username' parameter is deprecated."
}

variable "snowflake_password" {
  type        = string
  description = "Password for Snowflake user (use GitHub Secrets or env vars)."
  sensitive   = true
}

variable "snowflake_role" {
  type        = string
  description = "Snowflake role to use (e.g. SYSADMIN)."
  default     = "SYSADMIN"
}

variable "snowflake_warehouse" {
  type        = string
  description = "Snowflake Warehouse."
  default     = "COMPUTE_WH"
}

variable "database_name" {
  type        = string
  description = "Optional database name. If empty, will be derived from project_prefix."
  default     = ""
}

variable "schema_name" {
  type        = string
  description = "Optional schema name. If empty, will be derived from project_prefix."
  default     = ""
}
