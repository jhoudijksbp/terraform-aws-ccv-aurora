# TODO
# : Add Montoring module
# : Be able to configure thresholds for monitoring
# : Cluster parameter change
# : Database parameter change
# : Check perforamnce insights
# : Check enhanced monitoring
# : Check auditing
# : Fix warnings
# : Test this module

locals {
  aurora_clusters_map = flatten([
    for k, v in var.aurora_clusters : {
      apply_immediately                   = try(v.apply_immediately, true)
      backup_retention_period             = try(v.backup_retention_period, 2)
      cluster_family                      = try(v.cluster_family, "aurora-mysql5.7")
      cluster_parameters                  = try(v.cluster_parameters, [])
      database_parameters                 = try(v.database_parameters, [])
      deletion_protection                 = try(v.deletion_protection, false)
      engine                              = try(v.engine, "aurora-mysql")
      engine_mode                         = try(v.engine, "provisioned")
      engine_version                      = try(v.engine_version, "5.7.mysql_aurora.2.10.2")
      final_snapshot_identifier           = try(v.final_snapshot_identifier, replace("${v.stack}-fin-snapshot", "_", "-"))
      iam_database_authentication_enabled = try(v.iam_database_authentication_enabled, true)
      instance_class                      = try(v.instance_class, "db.r5.large")
      instance_count                      = try(v.instance_count, 1)
      master_username                     = try(v.master_username, "ccv_admin")
      monitoring_interval                 = try(v.monitoring_interval, 30)
      performance_insights                = try(v.performance_insights, true)
      stack                               = replace(v.stack, "_", "-")
  }])

  sql_users_map = [
    for k, v in var.sql_users : {
      authentication         = try(v.authentication, "credentials")
      password               = try(v.password, random_password.rds_aurora_random_password.result)
      privileges             = try(v.grants, "")
      rds_cluster_identifier = module.rds_aurora[replace(v.stack, "_", "-")].cluster_identifier
      rds_endpoint           = module.rds_aurora[replace(v.stack, "_", "-")].endpoint
      rds_port               = module.rds_aurora[replace(v.stack, "_", "-")].port
      rotation               = try(v.rotation, false)
      master_user            = try(v.master_user, false)
      src_host               = try(v.src_host, "%")
      username               = try(v.username, k)
    }
  ]
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
  source                              = "github.com/schubergphilis/terraform-aws-mcaf-aurora?ref=v0.4.7"
  stack                               = each.value.stack
  apply_immediately                   = each.value.apply_immediately
  backup_retention_period             = each.value.backup_retention_period
  cidr_blocks                         = var.cidr_blocks
  cluster_family                      = each.value.cluster_family
  cluster_parameters                  = each.value.cluster_parameters
  deletion_protection                 = each.value.deletion_protection
  database_parameters                 = each.value.database_parameters
  enabled_cloudwatch_logs_exports     = ["audit", "error", "general", "slowquery"]
  engine                              = each.value.engine
  engine_mode                         = each.value.engine_mode
  engine_version                      = each.value.engine_version
  final_snapshot_identifier           = each.value.final_snapshot_identifier
  iam_database_authentication_enabled = each.value.iam_database_authentication_enabled
  instance_class                      = each.value.instance_class
  instance_count                      = each.value.instance_count
  kms_key_id                          = var.kms_key_arn
  monitoring_interval                 = each.value.monitoring_interval
  password                            = random_password.rds_aurora_random_password.result
  performance_insights                = each.value.performance_insights
  subnet_ids                          = var.subnet_ids
  username                            = each.value.master_username
  tags                                = var.tags
}

module "rds_user_management" {
  count                    = "${length(var.sql_users) > 0 ? 1 : 0}"
  source                   = "app.terraform.io/ccv-group/rds-user-management/aws"
  version                  = "1.0.4"
  create_kms_iam_policy    = true
  create_vpc_secm_endpoint = true
  create_vpc_rds_endpoint  = true
  deploy_password_rotation = true
  kms_key_arn              = var.kms_key_arn
  sql_users                = local.sql_users_map
  subnet_ids               = var.subnet_ids
  vpc_id                   = var.vpc_id

  providers = {
    aws = aws
  }
}

#rds_instance_ids  = module.rds_aurora[*].instance_ids
#values(module.rds_aurora)[*].instance_ids[*]
#[for <ITEM> in <LIST> : <OUTPUT>]
#values(aws_secretsmanager_secret.application-secret)[*]["arn"]
module "rds_monitoring" {
  count             = "${var.enable_cloudwatch_monitoring == true ? 1 : 0}"
  source            = "app.terraform.io/ccv-group/rds-monitoring/aws"
  version           = "1.0.0"
  email_endpoint    = var.email_endpoint
  kms_key_id        = var.kms_key_arn
  rds_instance_ids  = values(module.rds_aurora)[*]["instance_ids"]
  send_email_alerts = "${length(var.email_endpoint) > 0 ? true : false}"
  tags              = var.tags
}
