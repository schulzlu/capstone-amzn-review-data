variable "org_name" {
  description = "Organization name of the snowflake account"
  type      = string
}

variable "account_name" {
  description = "Name of the snowflake account"
  type      = string
}

variable "snowflake_user" {
  description = "User of the snowflake account"
  type      = string
}

variable "snowflake_password" {
  description = "Password of the snowflake account"
  type      = string
  sensitive = true
}

variable "snowflake_aws_account_id" {
  description = "Complete arn of the aws user configured in snowflake"
  type      = string
  sensitive = true
}


variable "snowflake_role" {
  description = "Role of the snowflake account"
  type      = string
  default = "PUBLIC"
}

variable "snowflake_warehouse" {
  description = "Warehouse of the snowflake account"
  type      = string
  default = "COMPUTE_WH"
}

variable "database_name" {
  description = "Snowflake database name"
  type        = string
}

variable "schema_name" {
  description = "Snowflake schema name"
  type        = string
}

