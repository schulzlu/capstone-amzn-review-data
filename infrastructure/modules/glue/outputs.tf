output "job_name_ingest" {
  value = aws_glue_job.ingest.name
}
output "job_name_flatten" {
  value = aws_glue_job.flatten.name
}
output "crawler_name" {
  value = aws_glue_crawler.parquet_crawler.name
}

output "iam_role_arn" {
  value = aws_iam_role.glue.arn
}