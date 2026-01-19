variable "job_name" {
  description = "Glue job name"
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