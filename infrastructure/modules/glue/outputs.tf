output "job_arn" {
  value = aws_glue_job.ingest.name
}

output "iam_role_arn" {
  value = aws_iam_role.glue.arn
}