variable "aurora_clusters" {
  description = "List of Aurora cluster(s) to create/manage"
}

variable "cidr_blocks" {
  type        = list(string)
  default     = null
  description = "List of CIDR blocks that should be allowed access to the Aurora cluster"
}

variable "kms_key_id" {
  type        = string
  default     = null
  description = "The KMS key ID used for the storage encryption"
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
