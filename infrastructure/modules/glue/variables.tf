variable "job_name_ingest" {
  description = "Glue job name for ingest data"
  type        = string
}

variable "job_name_flat" {
  description = "Glue job name for flatten data"
  type        = string
}

variable "raw_bucket" {
  description = "S3 bucket for raw/landing data"
  type        = string
}


variable "script_bucket" {
  description = "S3 bucket where Glue scripts are stored"
  type        = string
}