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
# Glue Jobs
# ------------------------------------------------------------------
module "glue" {
  source = "./modules/glue"

  job_name_ingest = "raw-ingestion-job"
  job_name_flat   = "flatten-raw-data-job"

  script_bucket = module.s3.bucket_id
  raw_bucket    = module.s3.bucket_id
}

module "stepfunctions" {
  source              = "./modules/step_functions"
  script_bucket = module.s3.bucket_id
  raw_bucket    = module.s3.bucket_id

  # Both Glue job names from your glue module
  download_job_name = module.glue.job_name_ingest
  flatten_job_name  = module.glue.job_name_flatten
  crawler_name = module.glue.crawler_name

  poll_interval_seconds = 120

  depends_on = [
    module.glue,
    # module.lambda,
    # module.sns,
    # module.iam
  ]
}
