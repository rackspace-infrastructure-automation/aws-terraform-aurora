data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  is_postgres = "${var.engine == "aurora-postgres"}" # Allows setting postgres speciffic options

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
  family        = "${coalesce(var.family, join("", list(var.engine, local.major_version)))}"

  notification_set    = "${ var.notification_topic == "" ? 0 : 1 }"
  cluster_alarm_count = 2

  cluster_alarms = [
    {
      alarm_name         = "write-io-high"
      evaluation_periods = 6
      description        = "Write IO > ${var.alarm_write_io_limit}, sending notifcation..."
      operator           = "GreaterThanThreshold"
      threshold          = "${var.alarm_write_io_limit}"
      metric             = "VolumeWriteIOPs"
    },
    {
      alarm_name         = "read-io-high"
      evaluation_periods = 6
      description        = "Read IO > ${var.alarm_read_io_limit}, sending notifcation..."
      operator           = "GreaterThanThreshold"
      threshold          = "${var.alarm_read_io_limit}"
      metric             = "VolumeReadIOPs"
    },
  ]

  rs_alarm_topic = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rackspace-support-urgent"
  rs_alarm       = "${var.rackspace_alarms_enabled ? local.rs_alarm_topic : "" }"
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
  major_engine_version     = "${local.major_version}"

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

  engine         = "${var.engine}"
  engine_version = "${local.engine_version}"
  port           = "${local.port}"

  storage_encrypted = "${var.storage_encrypted}"
  kms_key_id        = "${var.kms_key_id}"

  database_name   = "${var.dbname}"
  master_username = "${var.username}"
  master_password = "${var.password}"

  replication_source_identifier = "${local.read_replica ? local.source_cluster_arn : "" }"
  source_region                 = "${local.read_replica ? var.source_region : "" }"
  snapshot_identifier           = "${var.db_snapshot_arn}"

  vpc_security_group_ids          = ["${var.security_groups}"]
  db_subnet_group_name            = "${local.subnet_group}"
  db_cluster_parameter_group_name = "${local.cluster_parameter_group}"

  backup_retention_period      = "${var.backup_retention_period}"
  preferred_backup_window      = "${var.backup_window}"
  preferred_maintenance_window = "${var.maintenance_window}"
  skip_final_snapshot          = "${local.read_replica}"
  final_snapshot_identifier    = "${var.name}-final-snapshot"

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
  count             = "${var.replica_instances + 1}"
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

  monitoring_interval = "${var.monitoring_interval}"
  monitoring_role_arn = "${local.monitoring_role_arn}"

  tags = "${merge(var.tags, local.tags)}"

  depends_on = ["aws_iam_role_policy_attachment.enhanced_monitoring_policy"]
}

resource "aws_cloudwatch_metric_alarm" "instance_alarms" {
  count = "${(var.replica_instances + 1)  * (var.rackspace_alarms_enabled || local.notification_set ? 1 : 0)}"

  alarm_name          = "${var.name}-${format("%02d",count.index+1)}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "15"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.alarm_cpu_limit}"
  alarm_description   = "CPU Utilization above ${var.alarm_cpu_limit} for 15 minutes.  Sending notifications..."
  alarm_actions       = ["${compact(list(var.notification_topic, local.rs_alarm))}"]
  ok_actions          = ["${compact(list(local.rs_alarm))}"]

  dimensions {
    DBInstanceIdentifier = "${element(aws_rds_cluster_instance.cluster_instance.*.id, count.index)}"
  }
}

resource "aws_cloudwatch_metric_alarm" "cluster_alarms" {
  count = "${local.cluster_alarm_count * (local.notification_set ? 1 : 0)}"

  alarm_name          = "${var.name}-${lookup(local.cluster_alarms[count.index], "alarm_name")}"
  comparison_operator = "${lookup(local.cluster_alarms[count.index], "operator")}"
  evaluation_periods  = "${lookup(local.cluster_alarms[count.index], "evaluation_periods")}"
  metric_name         = "${lookup(local.cluster_alarms[count.index], "metric")}"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "${lookup(local.cluster_alarms[count.index], "threshold")}"
  alarm_description   = "${lookup(local.cluster_alarms[count.index], "description")}"
  alarm_actions       = ["${compact(list(var.notification_topic))}"]

  dimensions {
    EngineName          = "${var.engine}"
    DbClusterIdentifier = "${aws_rds_cluster.db_cluster.id}"
  }
}
