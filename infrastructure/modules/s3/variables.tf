variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "enable_versioning" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Optional tags to attach to the bucket"
  type        = map(string)
  default     = {source:"terraform"}
}

variable "prefixes" {
  description = "List of S3 prefixes (folders) to create"
  type        = set(string)
  default     = []
}