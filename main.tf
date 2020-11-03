/**
 * # aws-terraform-aurora
 *
 * This module creates an aurora RDS cluster.  The module currently supports the aurora, aurora-mysql, and aurora-postgres engines.
 *
 * The module will output the required configuration files to enable client and worker node setup and configuration.
 *
 * ## Basic Usage
 *
 * ```HCL
 * module "aurora_master" {
 *   source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-aurora//?ref=v0.12.1"
 *
 *   binlog_format = "MIXED"
 *   engine        = "aurora"
 *
 *   instance_availability_zone_list = [
 *     "us-west-2a",
 *     "us-west-2b",
 *     "us-west-2c",
 *   ]
 *
 *   instance_class    = "db.t2.medium"
 *   name              = "sample-aurora-master"
 *   password          = "${data.aws_kms_secrets.rds_credentials.plaintext["password"]}"
 *   replica_instances = 2
 *   security_groups   = ["${module.vpc.default_sg}"]
 *   storage_encrypted = true
 *   subnets           = "${module.vpc.private_subnets}"
 * }
 * ```
 *
 * Full working references are available at [examples](examples)
 * ## Other TF Modules Used
 * Using [aws-terraform-cloudwatch_alarm](https://github.com/rackspace-infrastructure-automation/aws-terraform-cloudwatch_alarm) to create the following CloudWatch Alarms:
 *   - high_cpu
 *   - write_io_high
 *   - read_io_high
 */

terraform {
  required_version = ">= 0.12"

  required_providers {
    aws = ">= 2.7.0"
  }
}

data "aws_region" "current" {
}

data "aws_caller_identity" "current" {
}

locals {
  is_postgres = var.engine == "aurora-postgresql" # Allows setting postgres specific options

  # This map allows setting engine defaults.  Should be updated as new engine versions are released
  engine_defaults = {
    aurora = {
      version = "5.6.10a"
    }
    aurora-mysql = {
      version = "5.7.12"
    }
    aurora-postgresql = {
      port    = "5432"
      version = "9.6.17"
    }
  }

  # This section selects the explicitly defined variable first, the default provided in the above map next,
  # and finally an appropriate default value
  port = coalesce(
    var.port,
    lookup(local.engine_defaults[var.engine], "port", "3306"),
  )

  engine_version = coalesce(
    var.engine_version,
    local.engine_defaults[var.engine]["version"],
  )

  global_cluster_identifier = var.engine_mode == "global" ? var.global_cluster_identifier : ""

  # backtrack is only support in a very limited set of configurations. Below we determine if a compatible set
  # of parameters where provided
  backtrack_support = var.engine == "aurora" && var.engine_mode == "provisioned" && var.binlog_format == "OFF" ? true : false

  tags = {
    Environment     = var.environment
    Name            = var.name
    ServiceProvider = "Rackspace"
  }

  binlog_parameter = {
    apply_method = "pending-reboot"
    name         = "binlog_format"
    value        = var.binlog_format
  }

  cluster_parameters = {
    aurora            = [local.binlog_parameter]
    aurora-mysql      = [local.binlog_parameter]
    aurora-postgresql = []
  }

  options    = []
  parameters = []

  read_replica       = var.source_cluster != "" && var.source_region != ""
  source_cluster_arn = "arn:aws:rds:${var.source_region}:${data.aws_caller_identity.current.account_id}:cluster:${var.source_cluster}"

  # This section generates the major version by grabbing the first numeral for postgres,
  # and the first two for other engines
  version_chunk = chunklist(split(".", local.engine_version), local.is_postgres ? 1 : 2)

  major_version = join(".", local.version_chunk[0])

  # postgres 9 and >9 behave differently w.r.t family so this is an operation specifically  postgres 9
  is_postgres9   = var.engine == "aurora-postgresql" && local.major_version == "9"
  family         = coalesce(var.family, join("", [var.engine, local.family_version]))
  family_version = local.is_postgres9 ? join(".", concat(local.version_chunk[0], local.version_chunk[1])) : local.major_version
}

resource "aws_db_subnet_group" "db_subnet_group" {
  count = var.existing_subnet_group == "" ? 1 : 0

  description = "Database subnet group for ${var.name}"
  name_prefix = "${var.name}-"
  subnet_ids  = var.subnets

  tags = merge(var.tags, local.tags)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_parameter_group" "db_parameter_group" {
  count = var.existing_parameter_group_name == "" ? 1 : 0

  description = "Database parameter group for ${var.name}"
  family      = local.family
  name_prefix = "${var.name}-"

  dynamic "parameter" {
    for_each = concat(var.parameters, local.parameters)
    content {
      apply_method = lookup(parameter.value, "apply_method", null)
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }

  tags = merge(var.tags, local.tags)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_option_group" "db_option_group" {
  count = var.existing_option_group_name == "" ? 1 : 0

  engine_name              = var.engine
  name_prefix              = "${var.name}-"
  option_group_description = "Option group for ${var.name}"

  major_engine_version = local.family_version

  dynamic "option" {
    for_each = concat(var.options, local.options)
    content {
      db_security_group_memberships  = lookup(option.value, "db_security_group_memberships", null)
      option_name                    = option.value.option_name
      port                           = lookup(option.value, "port", null)
      version                        = lookup(option.value, "version", null)
      vpc_security_group_memberships = lookup(option.value, "vpc_security_group_memberships", null)

      dynamic "option_settings" {
        for_each = lookup(option.value, "option_settings", [])
        content {
          name  = option_settings.value.name
          value = option_settings.value.value
        }
      }
    }
  }

  tags = merge(var.tags, local.tags)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_rds_cluster_parameter_group" "db_cluster_parameter_group" {
  count = var.existing_cluster_parameter_group_name == "" ? 1 : 0

  # This resource does not utilize name_prefix.  This is due to a bug preventing unique names from being generated.
  # Currently using name directly.  If that proves to be troublesome, we can attempt to generate a
  # suffix using timestamps.  See https://github.com/terraform-providers/terraform-provider-aws/issues/1739
  # for further details
  name = var.name

  description = "Cluster parameter group for ${var.name}"
  family      = local.family

  dynamic "parameter" {
    for_each = concat(var.cluster_parameters, local.cluster_parameters[var.engine])
    content {
      apply_method = lookup(parameter.value, "apply_method", null)
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }

  tags = merge(var.tags, local.tags)

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["monitoring.rds.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "enhanced_monitoring_role" {
  count = var.existing_monitoring_role == "" && var.monitoring_interval > 0 ? 1 : 0

  name_prefix = "${var.name}-"

  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring_policy" {
  count = var.existing_monitoring_role == "" && var.monitoring_interval > 0 ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.enhanced_monitoring_role[0].name
}

locals {
  cluster_parameter_group = coalesce(
    var.existing_cluster_parameter_group_name,
    join(
      "",
      aws_rds_cluster_parameter_group.db_cluster_parameter_group.*.id,
    ),
  )
  option_group = coalesce(
    var.existing_option_group_name,
    join("", aws_db_option_group.db_option_group.*.id),
  )
  parameter_group = coalesce(
    var.existing_parameter_group_name,
    join("", aws_db_parameter_group.db_parameter_group.*.id),
  )
  subnet_group = coalesce(
    var.existing_subnet_group,
    join("", aws_db_subnet_group.db_subnet_group.*.id),
  )

  monitoring_role_arn = var.existing_monitoring_role == "" ? join("", aws_iam_role.enhanced_monitoring_role.*.arn) : var.existing_monitoring_role
}

# RDS Cluster

resource "aws_rds_cluster" "db_cluster" {
  cluster_identifier_prefix = "${var.name}-"
  global_cluster_identifier = local.global_cluster_identifier

  engine         = var.engine
  engine_mode    = var.engine_mode
  engine_version = local.engine_version
  port           = local.port

  kms_key_id        = var.kms_key_id
  storage_encrypted = var.storage_encrypted

  database_name   = var.dbname
  master_password = var.password
  master_username = var.username

  replication_source_identifier = local.read_replica ? local.source_cluster_arn : ""
  snapshot_identifier           = var.db_snapshot_arn
  source_region                 = local.read_replica ? var.source_region : ""

  deletion_protection = var.enable_delete_protection

  db_cluster_parameter_group_name = local.cluster_parameter_group
  db_subnet_group_name            = local.subnet_group
  vpc_security_group_ids          = var.security_groups

  backtrack_window             = local.backtrack_support ? var.backtrack_window : 0
  backup_retention_period      = var.backup_retention_period >= 1 && var.backup_retention_period <= 35 ? var.backup_retention_period : 35
  final_snapshot_identifier    = "${var.name}-final-snapshot"
  preferred_backup_window      = var.backup_window
  preferred_maintenance_window = var.maintenance_window
  skip_final_snapshot          = local.read_replica || var.skip_final_snapshot

  enabled_cloudwatch_logs_exports = var.cloudwatch_logs_exports

  tags = merge(var.tags, local.tags)

  # Option Group, Parameter Group, and Subnet Group and cluster parameter group added as the coalesce
  # to use any existing groups seems to throw off dependancies while destroying resources.
  depends_on = [
    aws_db_parameter_group.db_parameter_group,
    aws_db_option_group.db_option_group,
    aws_db_subnet_group.db_subnet_group,
    aws_rds_cluster_parameter_group.db_cluster_parameter_group,
  ]
}

# RDS Instances

resource "aws_rds_cluster_instance" "cluster_instance" {
  count = var.replica_instances + 1

  identifier_prefix = "${var.name}-${format("%02d", count.index + 1)}-"

  cluster_identifier = aws_rds_cluster.db_cluster.id
  engine             = var.engine
  engine_version     = local.engine_version
  instance_class     = var.instance_class
  promotion_tier     = count.index

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  publicly_accessible        = var.publicly_accessible

  availability_zone       = element(var.instance_availability_zone_list, count.index)
  db_parameter_group_name = local.parameter_group
  db_subnet_group_name    = local.subnet_group

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = local.monitoring_role_arn

  performance_insights_enabled    = var.performance_insights_enable
  performance_insights_kms_key_id = var.performance_insights_kms_key_id

  tags = merge(var.tags, local.tags)

  depends_on = [aws_iam_role_policy_attachment.enhanced_monitoring_policy]
}

data "null_data_source" "alarm_dimensions" {
  count = var.replica_instances + 1

  inputs = {
    DBInstanceIdentifier = element(aws_rds_cluster_instance.cluster_instance.*.id, count.index)
  }
}

resource "aws_route53_record" "cluster_record" {
  count = var.create_internal_zone_record ? 1 : 0

  name    = var.cluster_internal_record_name
  records = [aws_rds_cluster.db_cluster.endpoint]
  ttl     = "300"
  type    = "CNAME"
  zone_id = var.internal_zone_id
}

resource "aws_route53_record" "cluster_reader_record" {
  count = var.create_internal_zone_record ? 1 : 0

  name    = var.reader_internal_record_name
  records = [aws_rds_cluster.db_cluster.reader_endpoint]
  ttl     = "300"
  type    = "CNAME"
  zone_id = var.internal_zone_id
}

module "high_cpu" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-cloudwatch_alarm//?ref=v0.12.4"

  alarm_count              = var.replica_instances + 1
  alarm_description        = "CPU Utilization above ${var.alarm_cpu_limit} for 15 minutes.  Sending notifications..."
  alarm_name               = "${var.name}-high-cpu"
  comparison_operator      = "GreaterThanThreshold"
  customer_alarms_enabled  = true
  dimensions               = data.null_data_source.alarm_dimensions.*.outputs
  evaluation_periods       = 15
  metric_name              = "CPUUtilization"
  namespace                = "AWS/RDS"
  notification_topic       = var.notification_topic
  period                   = 60
  rackspace_alarms_enabled = var.rackspace_alarms_enabled
  rackspace_managed        = var.rackspace_managed
  severity                 = "urgent"
  statistic                = "Average"
  threshold                = var.alarm_cpu_limit
}

module "write_io_high" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-cloudwatch_alarm//?ref=v0.12.4"

  alarm_description        = "Write IO > ${var.alarm_write_io_limit}, sending notification..."
  alarm_name               = "${var.name}-write-io-high"
  comparison_operator      = "GreaterThanThreshold"
  customer_alarms_enabled  = true
  evaluation_periods       = 6
  metric_name              = "VolumeWriteIOPs"
  namespace                = "AWS/RDS"
  notification_topic       = var.notification_topic
  period                   = 300
  rackspace_alarms_enabled = false
  statistic                = "Average"
  threshold                = var.alarm_write_io_limit

  dimensions = [
    {
      EngineName          = var.engine
      DbClusterIdentifier = aws_rds_cluster.db_cluster.id
    },
  ]
}

module "read_io_high" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-cloudwatch_alarm//?ref=v0.12.4"

  alarm_description        = "Read IO > ${var.alarm_read_io_limit}, sending notification..."
  alarm_name               = "${var.name}-read-io-high"
  comparison_operator      = "GreaterThanThreshold"
  customer_alarms_enabled  = true
  evaluation_periods       = 6
  metric_name              = "VolumeReadIOPs"
  namespace                = "AWS/RDS"
  notification_topic       = var.notification_topic
  period                   = 300
  rackspace_alarms_enabled = false
  statistic                = "Average"
  threshold                = var.alarm_read_io_limit

  dimensions = [
    {
      EngineName          = var.engine
      DbClusterIdentifier = aws_rds_cluster.db_cluster.id
    },
  ]
}

