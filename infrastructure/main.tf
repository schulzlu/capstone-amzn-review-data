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
  }
}

provider "aws" {
  region = "eu-north-1"
}

#Creates a random bucket-id every time
resource "random_id" "rng" {
  keepers = {
    first = "${timestamp()}"
  }     
  byte_length = 8
}

module "amazon_data" {
  source      = "./modules/s3"
  bucket_name = "terraform-amazon-review-data-${random_id.rng.hex}"
  tags = {
    owner = "DATAENG"
    env   = "dev"
  }
}

output "bucket_id" {
  value = module.amazon_data.bucket_id
}