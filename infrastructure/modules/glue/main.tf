resource "aws_iam_role" "glue" {
  name = "glue-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "glue" {
  role = aws_iam_role.glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.raw_bucket}",
          "arn:aws:s3:::${var.raw_bucket}/*",
          "arn:aws:s3:::${var.script_bucket}",
          "arn:aws:s3:::${var.script_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:DeleteTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchCreatePartition",
          "glue:BatchGetPartition",
          "glue:BatchDeletePartition",
          "glue:BatchUpdatePartition"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# 🔹 Upload Glue script
resource "aws_s3_object" "ingest_glue_script" {
  bucket = var.script_bucket
  key    = "scripts/ingest_data.py"

  source = "${path.module}/jobs/ingest_data.py"
  etag   = filemd5("${path.module}/jobs/ingest_data.py")
}

resource "aws_s3_object" "flatten_glue_script" {
  bucket = var.script_bucket
  key    = "scripts/flatten_data.py"

  source = "${path.module}/jobs/flatten_data.py"
  etag   = filemd5("${path.module}/jobs/flatten_data.py")
}


# 🔹 Glue job
resource "aws_glue_job" "ingest" {
  name     = var.job_name_ingest
  role_arn = aws_iam_role.glue.arn

  command {
    name            = "glueetl"
    script_location = "s3://${var.script_bucket}/${aws_s3_object.ingest_glue_script.key}"
    python_version  = "3"
  }

  glue_version       = "4.0"
  number_of_workers = 2
  worker_type        = "G.1X"

  default_arguments = {
    "--RAW_BUCKET" = var.raw_bucket
    "--RAW_PREFIX" = "raw"
    "--TempDir"    = "s3://${var.script_bucket}/tmp/"
  }
}

resource "aws_glue_job" "flatten" {
  name     = var.job_name_flat
  role_arn = aws_iam_role.glue.arn

  command {
    name            = "glueetl"
    script_location = "s3://${var.script_bucket}/${aws_s3_object.flatten_glue_script.key}"
    python_version  = "3"
  }

  glue_version       = "4.0"
  number_of_workers = 2
  worker_type        = "G.1X"

  default_arguments = {
    "--RAW_BUCKET" = var.raw_bucket
    "--RAW_PREFIX" = "raw"
    "--FLATTENED_BUCKET" = var.raw_bucket
    "--FLATTENED_PREFIX" = "flattened"
    "--TempDir"    = "s3://${var.script_bucket}/tmp/"
  }
}

resource "aws_glue_crawler" "parquet_crawler" {
  name          = "amazon-review-parquet-crawler"
  role          = aws_iam_role.glue.arn
  database_name = aws_glue_catalog_database.parquet_db.name

  s3_target {
    path = "s3://${var.raw_bucket}/flattened/reviews/"
  }

  s3_target {
    path = "s3://${var.raw_bucket}/flattened/meta_data/"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })
}

# Glue catalog database
resource "aws_glue_catalog_database" "parquet_db" {
  name        = "amazon_review_db"
  description = "Database for parquet data processed by Glue job"
}
