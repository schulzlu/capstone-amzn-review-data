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
      source  = "hashicorp/aws"
    }
    snowflake = {
      source = "snowflakedb/snowflake"
      version = "2.12.0"
    }
  }
}

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
}

#Creates a random bucket-id every time
resource "random_id" "rng" {
  keepers = {
    first = "${timestamp()}"
  }     
  byte_length = 8
}

module "s3" {
  source      = "./modules/s3"
  bucket_name = "terraform-amazon-review-data-${random_id.rng.hex}"
  force_destroy = true   # dev only

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

module "snowflake" {
  source = "./modules/snowflake"

  org_name = var.org_name
  account_name      = var.account_name
  snowflake_user              = var.snowflake_user
  snowflake_password          = var.snowflake_password
  snowflake_role              = var.snowflake_role
  snowflake_warehouse         = var.snowflake_warehouse

  database_name = var.database_name
  schema_name   = var.schema_name
}

module "glue" {
  source = "./modules/glue"

  job_name       = "raw-ingestion-job"
  script_bucket  = module.s3.bucket_id
  raw_bucket     = module.s3.bucket_id
}