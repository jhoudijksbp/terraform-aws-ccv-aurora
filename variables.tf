variable "aurora_clusters" {
  description = "List of Aurora cluster(s) to create/manage"
}

variable "cidr_blocks" {
  type        = list(string)
  default     = null
  description = "List of CIDR blocks that should be allowed access to the Aurora cluster"
}

variable "create_kms_iam_policy" {
  type        = bool
  default     = false
  description = "Create a IAM policy for permissions on KMS keys for password rotation Lambda"
}

variable "create_vpc_rds_endpoint" {
  type        = bool
  default     = false
  description = "Create a VPC endpoint for RDS"
}

variable "create_vpc_secm_endpoint" {
  type        = bool
  default     = false
  description = "Create a VPC endpoint for SSM"
}

variable "enable_cloudwatch_monitoring" {
  type        = bool
  default     = true
  description = "Enable Cloudwatch monitoring module"
}

variable "email_endpoint" {
  type = string
  default = ""
  description = "E-mail for Cloudwatch notifications"
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "The KMS key ARN used for the storage encryption"
}

variable "sql_users" {
  description = "List of SQL users which should be managed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs to deploy Aurora in"
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the bucket"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy lambda"
}
