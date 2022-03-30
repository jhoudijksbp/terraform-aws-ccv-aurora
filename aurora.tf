# Password for master user. This will get overwritten by password rotation immediately
resource "random_password" "rds_aurora_random_password" {
  length           = 40
  special          = true
  min_special      = 5
  override_special = "!#$%^&*()-_=+[]{}<>:?"
  keepers = {
    pass_version = 1
  }

module "rds_test_export" {
  source                              = "github.com/schubergphilis/terraform-aws-mcaf-aurora?ref=v0.4.5"
  stack                               = "var.instance_name"
  apply_immediately                   = true
  backup_retention_period             = 2
  cidr_blocks                         = "var.cidr_blocks"
  cluster_family                      = "aurora-mysql5.7"
  deletion_protection                 = false
  enabled_cloudwatch_logs_exports     = ["audit", "error", "general", "slowquery"]
  engine                              = "aurora-mysql"
  engine_mode                         = "provisioned"
  engine_version                      = "2.10.2"
  iam_database_authentication_enabled = true
  instance_class                      = "var.instance_class"
  instance_count                      = "var.instance_count"
  kms_key_id                          = "var.kms_key_arn"
  monitoring_interval                 = 60
  password                            = random_password.rds_aurora_random_password.result
  performance_insights                = true
  subnet_ids                          = "var.private_subnets"
  username                            = "var.master_username"
  tags                                = "var.tags"
}
