###################
# VPC Configuration
###################

variable "existing_subnet_group" {
  description = "The existing DB subnet group to use for this cluster (OPTIONAL)"
  type        = "string"
  default     = ""
}

variable "security_groups" {
  description = "A list of EC2 security groups to assign to this resource"
  type        = "list"
}

variable "subnets" {
  description = "Subnets for RDS Instances"
  type        = "list"
}

#########################
# Backups and Maintenance
#########################

variable "backup_retention_period" {
  description = "The number of days for which automated backups are retained. Setting this parameter to a positive number enables backups. Setting this parameter to 0 disables automated backups. Compass best practice is 30 or more days."
  type        = "string"
  default     = 35
}

variable "backup_window" {
  description = "The daily time range during which automated backups are created if automated backups are enabled."
  type        = "string"
  default     = "05:00-06:00"
}

variable "backtrack_window" {
  description = "The target backtrack window, in seconds.  Defaults to 1 day. Setting only affects supported versions (currently MySQL 5.6). Disable by setting to '0'."
  type        = "string"
  default     = 86400
}

variable "db_snapshot_arn" {
  description = "The identifier for the DB cluster snapshot from which you want to restore."
  type        = "string"
  default     = ""
}

variable "maintenance_window" {
  description = "The weekly time range (in UTC) during which system maintenance can occur."
  type        = "string"
  default     = "Sun:07:00-Sun:08:00"
}

###########
# Basic RDS
###########

variable "instance_availability_zone_list" {
  description = <<HEREDOC
List of availability zones to place each aurora instance. Availability zone assignment is by index. The first AZ in the list is assigned to the first instance,
second AZ in the list to the second instance, third AZ in the list to the third instance, etc. Also please remember that the number of AZs specified here should equal to replica_instances + 1.
HEREDOC

  type    = "list"
  default = [""]
}

variable "dbname" {
  description = "The DB name to create. If omitted, no database is created initially"
  type        = "string"
  default     = ""
}

variable "engine" {
  description = "Database Engine Type.  Allowed values: aurora-mysql, aurora, aurora-postgresql"
  type        = "string"
  default     = "aurora-mysql"
}

variable "engine_version" {
  description = "Database Engine Minor Version http://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_CreateDBInstance.html"
  type        = "string"
  default     = ""
}

variable "engine_mode" {
  description = "The database engine mode. Allowed values: provisioned and global(aurora engine only)."
  type        = "string"
  default     = "provisioned"
}

variable "instance_class" {
  description = "The database instance type."
  type        = "string"
}

variable "name" {
  description = "The name prefix to use for the resources created in this module."
  type        = "string"
}

variable "port" {
  description = "The port on which the DB accepts connections"
  type        = "string"
  default     = ""
}

variable "global_cluster_identifier" {
  description = "Global Cluster identifier. Property of aws_rds_global_cluster (Ignored if engine_mode is not 'global')."
  type        = "string"
  default     = ""
}

#############
# Advance RDS
#############

variable "auto_minor_version_upgrade" {
  description = "Boolean value that indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window"
  type        = "string"
  default     = true
}

variable "binlog_format" {
  description = "Sets the desired format. Defaults to OFF. Should be set to MIXED if this Aurora cluster will replicate to another RDS Instance or cluster. Ignored for aurora-postgresql engine"
  type        = "string"
  default     = "OFF"
}

variable "cluster_parameters" {
  description = "List of custom cluster parameters to apply to the parameter group."
  type        = "list"
  default     = []
}

variable "create_internal_records" {
  description = "Create an internal Route 53 record for the RDS cluster and cluster reader. Default is false."
  type        = "string"
  default     = "false"
}

variable "family" {
  description = "Parameter Group Family Name (ex. aurora5.6, aurora-postgresql9.6, aurora-mysql5.7)"
  type        = "string"
  default     = ""
}

variable "enable_delete_protection" {
  description = "If the DB instance should have deletion protection enabled. The database can't be deleted when this value is set to true. The default is false"
  type        = "string"
  default     = "false"
}

variable "existing_cluster_parameter_group_name" {
  description = "The existing cluster parameter group to use for this instance. (OPTIONAL)"
  type        = "string"
  default     = ""
}

variable "existing_option_group_name" {
  description = "The existing option group to use for this instance. (OPTIONAL)"
  type        = "string"
  default     = ""
}

variable "existing_parameter_group_name" {
  description = "The existing parameter group to use for this instance. (OPTIONAL)"
  type        = "string"
  default     = ""
}

variable "internal_record_cluster" {
  description = "The full record name you would like to add as a CNAME for the cluster that matches your Hosted Zone. i.e. cluster.example.com"
  type        = "string"
  default     = ""
}

variable "internal_record_cluster_reader" {
  description = "The full record name you would like to add as a CNAME for the cluster reader. i.e. reader.example.com"
  type        = "string"
  default     = ""
}

variable "internal_zone_id" {
  description = "The zone id you would like the internal records for the cluster and reader to be created in. i.e. Z2QHD5YD1WXE9M"
  type        = "string"
  default     = ""
}

variable "kms_key_id" {
  description = "KMS Key Arn to use for storage encryption. (OPTIONAL)"
  type        = "string"
  default     = ""
}

variable "options" {
  description = "List of custom options to apply to the option group."
  type        = "list"
  default     = []
}

variable "parameters" {
  description = "List of custom parameters to apply to the parameter group."
  type        = "list"
  default     = []
}

variable "publicly_accessible" {
  description = "Boolean value that indicates whether the database instances are Internet-facing."
  type        = "string"
  default     = false
}

variable "replica_instances" {
  description = "The number of Aurora replica instances to create.  This can range from 0 to 15."
  type        = "string"
  default     = 1
}

variable "storage_encrypted" {
  description = "Specifies whether the DB instance is encrypted"
  type        = "string"
  default     = false
}

############
# Monitoring
############
variable "alarm_cpu_limit" {
  description = "CloudWatch CPUUtilization Threshold"
  type        = "string"
  default     = 60
}

variable "alarm_read_io_limit" {
  description = "CloudWatch Read IOPSLimit Threshold"
  type        = "string"
  default     = 100000
}

variable "alarm_write_io_limit" {
  description = "CloudWatch Write IOPSLimit Threshold"
  type        = "string"
  default     = 100000
}

variable "cloudwatch_logs_exports" {
  description = "List of log types to export to cloudwatch. If omitted, no logs will be exported. The following log types are supported: `audit`, `error`, `general`, `slowquery`."
  type        = "list"
  default     = []
}

variable "existing_monitoring_role" {
  description = "ARN of an existing enhanced monitoring role to use for this instance. (OPTIONAL)"
  type        = "string"
  default     = ""
}

variable "monitoring_interval" {
  description = "The interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance. To disable collecting Enhanced Monitoring metrics, specify 0. The default is 0. Valid Values: 0, 1, 5, 10, 15, 30, 60."
  type        = "string"
  default     = 0
}

variable "notification_topic" {
  description = "List of SNS Topic ARNs to use for customer notifications from CloudWatch alarms. (OPTIONAL)"
  type        = "list"
  default     = []
}

variable "performance_insights_enable" {
  description = "Specifies whether Performance Insights is enabled or not."
  type        = "string"
  default     = false
}

variable "performance_insights_kms_key_id" {
  description = "(Optional) The ARN for the KMS key to encrypt Performance Insights data. When specifying performance_insights_kms_key_id, performance_insights_enabled needs to be set to true."
  type        = "string"
  default     = ""
}

variable "rackspace_alarms_enabled" {
  description = "Specifies whether non-emergency rackspace alarms will create a ticket."
  type        = "string"
  default     = false
}

variable "rackspace_managed" {
  description = "Boolean parameter controlling if instance will be fully managed by Rackspace support teams, created CloudWatch alarms that generate tickets, and utilize Rackspace managed SSM documents."
  type        = "string"
  default     = true
}

################
# Authentication
################

variable "password" {
  description = "Password for the local administrator account."
  type        = "string"
}

variable "username" {
  description = "The name of master user for the client DB instance."
  type        = "string"
  default     = "dbadmin"
}

#######
# Other
#######

variable "environment" {
  description = "Application environment for which this network is being created. one of: ('Development', 'Integration', 'PreProduction', 'Production', 'QA', 'Staging', 'Test')"
  type        = "string"
  default     = "Development"
}

variable "skip_final_snapshot" {
  description = "Boolean value to control if the DB Cluster will take a final snapshot when destroyed.  This value should be set to false if a final snapshot is desired."
  type        = "string"
  default     = false
}

variable "source_cluster" {
  description = "The cluster ID of the master Aurora cluster that will replicate to the created cluster. The master must be in a different region. Leave this parameter blank to create a master Aurora cluster."
  type        = "string"
  default     = ""
}

variable "source_region" {
  description = "The region of the master Aurora cluster that will replicate to the created cluster. The master must be in a different region. Leave this parameter blank to create a master Aurora cluster."
  type        = "string"
  default     = ""
}

variable "tags" {
  description = "Custom tags to apply to all resources."
  type        = "map"
  default     = {}
}
