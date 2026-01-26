terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.12.0"
    }
  }
}

locals {
  project_prefix           = var.project_prefix
  effective_database_name  = var.database_name != "" ? var.database_name : "${local.project_prefix}_db"
  effective_schema_name    = var.schema_name   != "" ? var.schema_name   : "${local.project_prefix}_schema"
}

resource "snowflake_database" "this" {
  name    = local.effective_database_name
}

resource "snowflake_schema" "this" {
  name     = local.effective_schema_name
  database = snowflake_database.this.name
}