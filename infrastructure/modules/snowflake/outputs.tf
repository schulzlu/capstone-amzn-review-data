output "snowflake_database" {
  description = "Created Snowflake database name"
  value       = snowflake_database.this.name
}

output "snowflake_schema" {
  description = "Created Snowflake schema name"
  value       = snowflake_schema.this.name
}