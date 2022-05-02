# TODO
# : Add User management module functionality
# : Add Montoring module
# : Database/cluster parameter change (how) 

locals {
  aurora_clusters_map = flatten([
    for k, v in var.aurora_clusters : {
      apply_immediately                   = try(v.apply_immediately, true)
      backup_retention_period             = try(v.backup_retention_period, 2)
      cidr_blocks                         = v.cidr_blocks
      cluster_family                      = try(v.cluster_family, "aurora-mysql5.7")
      cluster_parameters                  = try(v.cluster_parameters, [])
      database_parameters                 = try(v.database_parameters, [])
      deletion_protection                 = try(v.deletion_protection, false)
      engine                              = try(v.engine, "aurora-mysql")
      engine_mode                         = try(v.engine, "provisioned")
      engine_version                      = try(v.engine_version, "5.7.mysql_aurora.2.10.2")
      final_snapshot_identifier           = try(v.final_snapshot_identifier, "${v.stack}-fin-snapshot")
      iam_database_authentication_enabled = try(v.iam_database_authentication_enabled, true)
      instance_class                      = try(v.instance_class, "db.r5.large")
      instance_count                      = try(v.instance_count, 1)
      kms_key_id                          = v.kms_key_id
      master_username                     = try(v.master_username, "ccv_admin")
      monitoring_interval                 = try(v.monitoring_interval, 30)
      performance_insights                = try(v.performance_insights, true)
      stack                               = replace(v.stack, "_", "-")
      subnet_ids                          = v.subnet_ids
  }])
}

# Password for master user. This will get overwritten by password rotation immediately
resource "random_password" "rds_aurora_random_password" {
  length           = 40
  special          = true
  min_special      = 5
  override_special = "!#$%^&*()-_=+[]{}<>:?"
  keepers = {
    pass_version = 1
  }
}

module "rds_aurora" {
  for_each                            = { for cluster in local.aurora_clusters_map : cluster.stack => cluster }
  source                              = "github.com/schubergphilis/terraform-aws-mcaf-aurora?ref=v0.4.5"
  stack                               = each.value.stack
  apply_immediately                   = each.value.apply_immediately
  backup_retention_period             = each.value.backup_retention_period
  cidr_blocks                         = each.value.cidr_blocks
  cluster_family                      = each.value.cluster_family
  cluster_parameters                  = each.value.cluster_parameters
  deletion_protection                 = each.value.deletion_protection
  database_parameters                 = each.value.database_parameters
  enabled_cloudwatch_logs_exports     = ["audit", "error", "general", "slowquery"]
  engine                              = each.value.engine
  engine_mode                         = each.value.engine_mode
  engine_version                      = each.value.engine_version
  iam_database_authentication_enabled = each.value.iam_database_authentication_enabled
  instance_class                      = each.value.instance_class
  instance_count                      = each.value.instance_count
  kms_key_id                          = each.value.kms_key_id
  monitoring_interval                 = each.value.monitoring_interval
  password                            = random_password.rds_aurora_random_password.result
  performance_insights                = each.value.performance_insights
  subnet_ids                          = each.value.subnet_ids
  username                            = each.value.master_username
  tags                                = var.tags
}
