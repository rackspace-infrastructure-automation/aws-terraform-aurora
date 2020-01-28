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
 *   source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-aurora//?ref=v0.0.7"
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
 *	 - high_cpu
 *   - write_io_high
 *   - read_io_high
 */

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  is_postgres = "${var.engine == "aurora-postgresql"}" # Allows setting postgres specific options

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
      version = "9.6.8"
    }
  }

  # This section selects the explicitly defined variable first, the default provided in the above map next,
  # and finally an appropriate default value
  port = "${coalesce(var.port, lookup(local.engine_defaults[var.engine], "port", "3306"))}"

  engine_version = "${coalesce(var.engine_version, lookup(local.engine_defaults[var.engine], "version"))}"

  global_cluster_identifier = "${var.engine_mode == "global" ? var.global_cluster_identifier : ""}"

  # backtrack is only support in a very limited set of configurations. Below we determine if a compatible set
  # of parameters where provided
  backtrack_support = "${var.engine == "aurora" && var.engine_mode == "provisioned" && var.binlog_format == "OFF" ? true : false}"

  tags {
    Name            = "${var.name}"
    ServiceProvider = "Rackspace"
    Environment     = "${var.environment}"
  }

  binlog_parameter = {
    name         = "binlog_format"
    value        = "${var.binlog_format}"
    apply_method = "pending-reboot"
  }

  cluster_parameters = {
    aurora-postgresql = []
    aurora            = ["${local.binlog_parameter}"]
    aurora-mysql      = ["${local.binlog_parameter}"]
  }

  parameters = []
  options    = []

  read_replica       = "${var.source_cluster != "" && var.source_region != ""}"
  source_cluster_arn = "arn:aws:rds:${var.source_region}:${data.aws_caller_identity.current.account_id}:cluster:${var.source_cluster}"

  # This section generates the major version by grabbing the first numeral for postgres,
  # and the first two for other engines
  version_chunk = "${chunklist(split(".", local.engine_version), local.is_postgres ? 1 : 2)}"

  major_version = "${join(".", local.version_chunk[0])}"

  # postgres 9 and >9 behave differently w.r.t family so this is an operation specifically  postgres 9
  is_postgres9   = "${var.engine == "aurora-postgresql" && local.major_version == 9}"
  family_version = "${local.is_postgres9 ? join(".", concat(local.version_chunk[0],local.version_chunk[1]))  : local.major_version }"
  family         = "${coalesce(var.family, join("", list(var.engine, local.family_version)))}"
}

resource "aws_db_subnet_group" "db_subnet_group" {
  count = "${var.existing_subnet_group == "" ? 1 : 0}"

  name_prefix = "${var.name}-"
  description = "Database subnet group for ${var.name}"
  subnet_ids  = ["${var.subnets}"]

  tags = "${merge(var.tags, local.tags)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_parameter_group" "db_parameter_group" {
  count = "${var.existing_parameter_group_name == "" ? 1 : 0}"

  name_prefix = "${var.name}-"
  description = "Database parameter group for ${var.name}"
  family      = "${local.family}"

  parameter = "${concat(var.parameters, local.parameters)}"

  tags = "${merge(var.tags, local.tags)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_option_group" "db_option_group" {
  count = "${var.existing_option_group_name == "" ? 1 : 0}"

  name_prefix              = "${var.name}-"
  option_group_description = "Option group for ${var.name}"
  engine_name              = "${var.engine}"

  major_engine_version = "${local.family_version}"

  option = "${concat(var.options, local.options)}"

  tags = "${merge(var.tags, local.tags)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_rds_cluster_parameter_group" "db_cluster_parameter_group" {
  count = "${var.existing_cluster_parameter_group_name == "" ? 1 : 0}"

  # This resource does not utilize name_prefix.  This is due to a bug preventing unique names from being generated.
  # Currently using name directly.  If that proves to be troublesome, we can attempt to generate a
  # suffix using timestamps.  See https://github.com/terraform-providers/terraform-provider-aws/issues/1739
  # for further details
  name = "${var.name}"

  description = "Cluster parameter group for ${var.name}"
  family      = "${local.family}"

  parameter = "${concat(var.cluster_parameters, local.cluster_parameters[var.engine])}"

  tags = "${merge(var.tags, local.tags)}"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "enhanced_monitoring_role" {
  count = "${var.existing_monitoring_role == ""  && var.monitoring_interval > 0 ? 1 : 0}"

  name_prefix = "${var.name}-"

  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring_policy" {
  count = "${var.existing_monitoring_role == ""  && var.monitoring_interval > 0 ? 1 : 0}"

  role       = "${aws_iam_role.enhanced_monitoring_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

locals {
  subnet_group            = "${coalesce(var.existing_subnet_group, join("", aws_db_subnet_group.db_subnet_group.*.id))}"
  parameter_group         = "${coalesce(var.existing_parameter_group_name, join("", aws_db_parameter_group.db_parameter_group.*.id))}"
  cluster_parameter_group = "${coalesce(var.existing_cluster_parameter_group_name, join("", aws_rds_cluster_parameter_group.db_cluster_parameter_group.*.id))}"
  option_group            = "${coalesce(var.existing_option_group_name, join("", aws_db_option_group.db_option_group.*.id))}"
  monitoring_role_arn     = "${coalesce(var.existing_monitoring_role, join("", aws_iam_role.enhanced_monitoring_role.*.arn))}"
}

# RDS Cluster

resource "aws_rds_cluster" "db_cluster" {
  cluster_identifier_prefix = "${var.name}-"
  global_cluster_identifier = "${local.global_cluster_identifier}"

  engine         = "${var.engine}"
  engine_version = "${local.engine_version}"
  port           = "${local.port}"
  engine_mode    = "${var.engine_mode}"

  storage_encrypted = "${var.storage_encrypted}"
  kms_key_id        = "${var.kms_key_id}"

  database_name   = "${var.dbname}"
  master_username = "${var.username}"
  master_password = "${var.password}"

  replication_source_identifier = "${local.read_replica ? local.source_cluster_arn : "" }"
  source_region                 = "${local.read_replica ? var.source_region : "" }"
  snapshot_identifier           = "${var.db_snapshot_arn}"

  deletion_protection = "${var.enable_delete_protection}"

  vpc_security_group_ids          = ["${var.security_groups}"]
  db_subnet_group_name            = "${local.subnet_group}"
  db_cluster_parameter_group_name = "${local.cluster_parameter_group}"

  backup_retention_period      = "${var.backup_retention_period > 1 && var.backup_retention_period  <= 35 ? var.backup_retention_period : 35 }"
  preferred_backup_window      = "${var.backup_window}"
  backtrack_window             = "${local.backtrack_support ? var.backtrack_window: 0 }"
  preferred_maintenance_window = "${var.maintenance_window}"
  skip_final_snapshot          = "${local.read_replica || var.skip_final_snapshot}"
  final_snapshot_identifier    = "${var.name}-final-snapshot"

  enabled_cloudwatch_logs_exports = "${var.cloudwatch_logs_exports}"

  tags = "${merge(var.tags, local.tags)}"

  # Option Group, Parameter Group, and Subnet Group and cluster parameter group added as the coalesce
  # to use any existing groups seems to throw off dependancies while destroying resources.
  depends_on = [
    "aws_db_parameter_group.db_parameter_group",
    "aws_db_option_group.db_option_group",
    "aws_db_subnet_group.db_subnet_group",
    "aws_rds_cluster_parameter_group.db_cluster_parameter_group",
  ]
}

# RDS Instances

resource "aws_rds_cluster_instance" "cluster_instance" {
  count = "${var.replica_instances + 1}"

  identifier_prefix = "${var.name}-${format("%02d",count.index+1)}-"

  engine             = "${var.engine}"
  engine_version     = "${local.engine_version}"
  instance_class     = "${var.instance_class}"
  cluster_identifier = "${aws_rds_cluster.db_cluster.id}"
  promotion_tier     = "${count.index}"

  auto_minor_version_upgrade = "${var.auto_minor_version_upgrade}"
  publicly_accessible        = "${var.publicly_accessible}"

  db_subnet_group_name    = "${local.subnet_group}"
  db_parameter_group_name = "${local.parameter_group}"
  availability_zone       = "${element(var.instance_availability_zone_list, count.index)}"

  monitoring_interval = "${var.monitoring_interval}"
  monitoring_role_arn = "${local.monitoring_role_arn}"

  performance_insights_enabled    = "${var.performance_insights_enable}"
  performance_insights_kms_key_id = "${var.performance_insights_kms_key_id}"

  tags = "${merge(var.tags, local.tags)}"

  depends_on = ["aws_iam_role_policy_attachment.enhanced_monitoring_policy"]
}

data "null_data_source" "alarm_dimensions" {
  count = "${var.replica_instances + 1}"

  inputs = {
    DBInstanceIdentifier = "${element(aws_rds_cluster_instance.cluster_instance.*.id, count.index)}"
  }
}

resource "aws_route53_record" "cluster_record" {
  count   = "${var.create_internal_records ? 1:0}"
  zone_id = "${var.internal_zone_id}"
  name    = "${var.internal_record_cluster}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_rds_cluster.db_cluster.endpoint}"]
}

resource "aws_route53_record" "cluster_reader_record" {
  count   = "${var.create_internal_records ? 1:0}"
  zone_id = "${var.internal_zone_id}"
  name    = "${var.internal_record_cluster_reader}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_rds_cluster.db_cluster.reader_endpoint}"]
}

module "high_cpu" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-cloudwatch_alarm//?ref=v0.0.1"

  alarm_count              = "${var.replica_instances + 1}"
  alarm_description        = "CPU Utilization above ${var.alarm_cpu_limit} for 15 minutes.  Sending notifications..."
  alarm_name               = "${var.name}-high-cpu"
  comparison_operator      = "GreaterThanThreshold"
  customer_alarms_enabled  = true
  dimensions               = "${data.null_data_source.alarm_dimensions.*.outputs}"
  evaluation_periods       = 15
  metric_name              = "CPUUtilization"
  namespace                = "AWS/RDS"
  notification_topic       = "${var.notification_topic}"
  period                   = 60
  rackspace_alarms_enabled = "${var.rackspace_alarms_enabled}"
  rackspace_managed        = "${var.rackspace_managed}"
  severity                 = "urgent"
  statistic                = "Average"
  threshold                = "${var.alarm_cpu_limit}"
}

module "write_io_high" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-cloudwatch_alarm//?ref=v0.0.1"

  alarm_description        = "Write IO > ${var.alarm_write_io_limit}, sending notification..."
  alarm_name               = "${var.name}-write-io-high"
  comparison_operator      = "GreaterThanThreshold"
  customer_alarms_enabled  = true
  evaluation_periods       = 6
  metric_name              = "VolumeWriteIOPs"
  namespace                = "AWS/RDS"
  notification_topic       = "${var.notification_topic}"
  period                   = 300
  rackspace_alarms_enabled = false
  statistic                = "Average"
  threshold                = "${var.alarm_write_io_limit}"

  dimensions = [{
    EngineName          = "${var.engine}"
    DbClusterIdentifier = "${aws_rds_cluster.db_cluster.id}"
  }]
}

module "read_io_high" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-cloudwatch_alarm//?ref=v0.0.1"

  alarm_description        = "Read IO > ${var.alarm_read_io_limit}, sending notification..."
  alarm_name               = "${var.name}-read-io-high"
  comparison_operator      = "GreaterThanThreshold"
  customer_alarms_enabled  = true
  evaluation_periods       = 6
  metric_name              = "VolumeReadIOPs"
  namespace                = "AWS/RDS"
  notification_topic       = "${var.notification_topic}"
  period                   = 300
  rackspace_alarms_enabled = false
  statistic                = "Average"
  threshold                = "${var.alarm_read_io_limit}"

  dimensions = [{
    EngineName          = "${var.engine}"
    DbClusterIdentifier = "${aws_rds_cluster.db_cluster.id}"
  }]
}
