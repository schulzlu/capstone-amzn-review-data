terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
      version = "2.12.0"
    }
  }
}

resource "snowflake_database" "this" {
  name    = var.database_name
  comment = "Managed by Terraform"
}

resource "snowflake_schema" "this" {
  name     = var.schema_name
  database = snowflake_database.this.name
  comment  = "Managed by Terraform"
}


