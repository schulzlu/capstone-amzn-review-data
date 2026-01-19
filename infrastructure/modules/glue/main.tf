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
          "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# 🔹 Upload Glue script
resource "aws_s3_object" "glue_script" {
  bucket = var.script_bucket
  key    = "scripts/ingest_data.py"

  source = "${path.module}/jobs/ingest_data.py"
  etag   = filemd5("${path.module}/jobs/ingest_data.py")
}

# 🔹 Glue job
resource "aws_glue_job" "ingest" {
  name     = var.job_name
  role_arn = aws_iam_role.glue.arn

  command {
    name            = "glueetl"
    script_location = "s3://${var.script_bucket}/${aws_s3_object.glue_script.key}"
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
