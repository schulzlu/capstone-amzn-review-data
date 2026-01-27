############################################
# Step Functions module variables
############################################

# variable "project" {
#   type    = string
#   default = "capstone-amazon"
# }

# variable "env" {
#   type    = string
#   default = "dev"
# }

variable "raw_bucket" {
  description = "S3 bucket for raw/landing data"
  type        = string
}


variable "script_bucket" {
  description = "S3 bucket where Glue scripts are stored"
  type        = string
}

# variable "sfn_role_arn" {
#   description = "IAM role ARN for Step Functions"
#   type        = string
# }

# variable "lambda_function_arn" {
#   description = "Lambda function ARN for notifications"
#   type        = string
# }

variable "download_job_name" {
  description = "Glue job name for the dataset download job"
  type        = string
}

variable "flatten_job_name" {
  description = "Glue job name for the flatten job"
  type        = string
}

variable "crawler_name" {
  description = "Glue crawler name"
  type        = string
}

# variable "sns_topic_arn" {
#   description = "SNS topic ARN for optional Step Function notifications"
#   type        = string
#   default     = ""
# }

variable "poll_interval_seconds" {
  description = "Optional polling interval (seconds) used internally or for documentation"
  type        = number
  default     = 60
}