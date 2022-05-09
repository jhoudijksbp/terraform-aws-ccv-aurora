locals {

   # Default set of cluster parameters. It is possible to override this per parameter.
   cluster_parameters_default = {
     "character_set_server" = {
       value = "utf8mb4"
     },
     "character_set_client" = {
       value = "utf8mb4"
     },
     "character_set_connection" = {
       value = "utf8mb4"
     },
     "character_set_connection" = {
       value = "utf8mb4"
     },
     "character_set_filesystem" = {
       value = "utf8mb4"
     },
     "slow_query_log" = {
       value = 1
     },
     "server_audit_logging" = {
       value = 1
     },
     "server_audit_logs_upload" = {
       value = 1
     },
     "server_audit_events" = {
       value = "CONNECT,QUERY"
     },
     "server_audit_incl_users" = {
       value = "admin_user"
     },
   }

   # Default set of database parameters. It is possible to override this per parameter.
   database_parameters_default = {
    "max_connections" = {
      value = 3000
    },
    "general_log" = {
      value = 0
    },
    "slow_query_log" = {
      value = 1
    },
    "max_connect_errors" = {
      value = 4294967295
    },
    "max_allowed_packet" = {
      value = 67108864
    }
   }

  # A map of al cluster settings. This map is used to configure the RDS Aurora MCAF and RDS Aurora monitoring module
  aurora_clusters_map = flatten([
    for k, v in var.aurora_clusters : {
      apply_immediately                   = try(v.apply_immediately, true)
      backup_retention_period             = try(v.backup_retention_period, 2)
      cluster_family                      = try(v.cluster_family, "aurora-mysql5.7")
      cpu_utilization_too_high_threshold  = try(v.cpu_utilization_too_high_threshold, 90)
      disable_actions_blocks              = try(v.disable_actions_blocks, [])
      disable_actions_cpu                 = try(v.disable_actions_cpu, [])
      disable_actions_lag                 = try(v.disable_actions_lag, [])
      deletion_protection                 = try(v.deletion_protection, false)
      email_endpoint                      = try(v.email_endpoint, "")
      engine                              = try(v.engine, "aurora-mysql")
      engine_mode                         = try(v.engine, "provisioned")
      engine_version                      = try(v.engine_version, "5.7.mysql_aurora.2.10.2")
      evaluation_period                   = try(v.evaluation_period, 5)
      final_snapshot_identifier           = try(v.final_snapshot_identifier, replace("${v.stack}-fin-snapshot", "_", "-"))
      iam_database_authentication_enabled = try(v.iam_database_authentication_enabled, true)
      instance_class                      = try(v.instance_class, "db.r5.large")
      instance_count                      = try(v.instance_count, 1)
      master_username                     = v.master_username
      monitoring_interval                 = try(v.monitoring_interval, 30)
      performance_insights                = try(v.performance_insights, true)
      replicalag_threshold                = try(v.replicalag_threshold, 300000)
      stack                               = replace(v.stack, "_", "-")
      statistic_period                    = try(v.statistic_period, 60)

      # This is allowing to override cluster parameters in configuring this module
      cluster_parameters = [
        for k in setunion(keys(local.cluster_parameters_default), keys(try(v.cluster_parameters, {}))) : {
          name = k
          value = tostring(coalesce(
            try(v.cluster_parameters[k].value, null),
            k == "server_audit_incl_users" ? v.master_username : local.cluster_parameters_default[k].value,
            try(local.cluster_parameters_default[k].value, null),
          ))
        }
      ]

      # This is allowing to override database parameters in configuring this module
      database_parameters = [
        for k in setunion(keys(local.database_parameters_default), keys(try(v.database_parameters, {}))) : {
          name = k
          value = tostring(coalesce(
            try(v.database_parameters[k].value, null),
            try(local.database_parameters_default[k].value, null),
          ))
        }
      ]
  
  }])

  # We need a master user for each cluster. Based on this map secret is created and password rotation is enabled.
  master_users_map = [
    for k,v in var.aurora_clusters : {
      authentication         = "credentials"
      password               = random_password.rds_aurora_random_password.result
      privileges             = ""
      rds_cluster_identifier = module.rds_aurora[replace(v.stack, "_", "-")].cluster_identifier
      rds_endpoint           = module.rds_aurora[replace(v.stack, "_", "-")].endpoint
      rds_port               = module.rds_aurora[replace(v.stack, "_", "-")].port
      rotation               = true
      master_user            = true
      src_host               = try(v.master_user_src_host, "%")
      username               = v.master_username
    }
  ]

  # We need this because we can't use the instance_ids (from rds_aurora module) in the for_each of the rds monitoring module
  monitoring_instances_list = flatten([
    for k,v in var_aurora_clusters : [
      for i in range(var.instance_count) : {
        stack   = v.stack
        counter = i
      }
    ]
  ])

  # We need a map for all the configured SQL users. This will be used to create secrets, password rotation in the RDS user management module
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

  # Concatenation of the normal SQL users and all the master users.
  all_users = concat(local.master_users_map, local.sql_users_map)
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

# Deploy all RDS cluster/instances
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

# deploy the monitoring for all instances
module "rds_monitoring" {
  for_each                           = { for cluster in local.aurora_clusters_map : cluster.stack => cluster }
  source                             = "github.com/jhoudijksbp/terraform-aws-rds-monitoring"
  #source                             = "app.terraform.io/ccv-group/rds-monitoring/aws"
  #version                            = "1.0.0"
  cpu_utilization_too_high_threshold = each.value.cpu_utilization_too_high_threshold
  disable_actions_blocks             = each.value.disable_actions_blocks
  disable_actions_cpu                = each.value.disable_actions_cpu
  disable_actions_lag                = each.value.disable_actions_lag
  email_endpoint                     = each.value.email_endpoint
  evaluation_period                  = each.value.evaluation_period
  kms_key_id                         = var.kms_key_arn
  monitoring_instances_list          = local.monitoring_instances_list
  rds_instance_ids                   = module.rds_aurora[each.value.stack].instance_ids
  replicalag_threshold               = each.value.replicalag_threshold
  send_email_alerts                  = "${length(each.value.email_endpoint) > 0 ? true : false}"
  statistic_period                   = each.value.statistic_period
  tags                               = var.tags
}

# Deploy usermanagement and password rotation
module "rds_user_management" {
  count                    = "${length(var.sql_users) > 0 ? 1 : 0}"
  source                   = "app.terraform.io/ccv-group/rds-user-management/aws"
  version                  = "1.0.4"
  create_kms_iam_policy    = var.create_kms_iam_policy
  create_vpc_secm_endpoint = var.create_vpc_secm_endpoint
  create_vpc_rds_endpoint  = var.create_vpc_rds_endpoint
  deploy_password_rotation = true
  kms_key_arn              = var.kms_key_arn
  sql_users                = local.all_users
  subnet_ids               = var.subnet_ids
  vpc_id                   = var.vpc_id

  providers = {
    aws = aws
  }
}
