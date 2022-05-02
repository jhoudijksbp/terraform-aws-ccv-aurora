variable "aurora_clusters" {
  description = "List of Aurora cluster(s) to create/manage"
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the bucket"
}
