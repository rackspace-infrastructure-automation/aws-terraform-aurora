
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| alarm_cpu_limit | CloudWatch CPUUtilization Threshold | string | `60` | no |
| alarm_read_io_limit | CloudWatch Read IOPSLimit Threshold | string | `100000` | no |
| alarm_write_io_limit | CloudWatch Write IOPSLimit Threshold | string | `100000` | no |
| auto_minor_version_upgrade | Boolean value that indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window | string | `true` | no |
| backup_retention_period | The number of days for which automated backups are retained. Setting this parameter to a positive number enables backups. Setting this parameter to 0 disables automated backups. Compass best practice is 30 or more days. | string | `35` | no |
| backup_window | The daily time range during which automated backups are created if automated backups are enabled. | string | `05:00-06:00` | no |
| binlog_format | Sets the desired format. Defaults to OFF. Should be set to MIXED if this Aurora cluster will replicate to another RDS Instance or cluster. Ignored for aurora-postgresql engine | string | `OFF` | no |
| cluster_parameters | List of custom cluster parameters to apply to the parameter group. | list | `<list>` | no |
| db_snapshot_arn | The identifier for the DB cluster snapshot from which you want to restore. | string | `` | no |
| dbname | The DB name to create. If omitted, no database is created initially | string | `` | no |
| engine | Database Engine Type.  Allowed values: aurora-mysql, aurora-postgresql, aurora | string | `aurora-mysql` | no |
| engine_version | Database Engine Minor Version http://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_CreateDBInstance.html | string | `` | no |
| environment | Application environment for which this network is being created. one of: ('Development', 'Integration', 'PreProduction', 'Production', 'QA', 'Staging', 'Test') | string | `Development` | no |
| existing_cluster_parameter_group_name | The existing cluster parameter group to use for this instance. (OPTIONAL) | string | `` | no |
| existing_monitoring_role | ARN of an existing enhanced monitoring role to use for this instance. (OPTIONAL) | string | `` | no |
| existing_option_group_name | The existing option group to use for this instance. (OPTIONAL) | string | `` | no |
| existing_parameter_group_name | The existing parameter group to use for this instance. (OPTIONAL) | string | `` | no |
| existing_subnet_group | The existing DB subnet group to use for this cluster (OPTIONAL) | string | `` | no |
| family | Parameter Group Family Name (ex. aurora5.6, aurora-postgresql9.6, aurora-mysql5.7) | string | `` | no |
| instance_class | The database instance type. | string | - | yes |
| kms_key_id | KMS Key Arn to use for storage encryption. (OPTIONAL) | string | `` | no |
| maintenance_window | The weekly time range (in UTC) during which system maintenance can occur. | string | `Sun:07:00-Sun:08:00` | no |
| monitoring_interval | The interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance. To disable collecting Enhanced Monitoring metrics, specify 0. The default is 0. Valid Values: 0, 1, 5, 10, 15, 30, 60. | string | `0` | no |
| name | The name prefix to use for the resources created in this module. | string | - | yes |
| notification_topic | SNS Topic ARN to use for customer notifications from CloudWatch alarms. (OPTIONAL) | string | `` | no |
| options | List of custom options to apply to the option group. | list | `<list>` | no |
| parameters | List of custom parameters to apply to the parameter group. | list | `<list>` | no |
| password | Password for the local administrator account. | string | - | yes |
| port | The port on which the DB accepts connections | string | `` | no |
| publicly_accessible | Boolean value that indicates whether the database instances are Internet-facing. | string | `false` | no |
| rackspace_alarms_enabled | Specifies whether non-emergency rackspace alarms will create a ticket. | string | `false` | no |
| replica_instances | The number of Aurora replica instances to create.  This can range from 0 to 15. | string | `1` | no |
| security_groups | A list of EC2 security groups to assign to this resource | list | - | yes |
| source_cluster | The cluster ID of the master Aurora cluster that will replicate to the created cluster. The master must be in a different region. Leave this parameter blank to create a master Aurora cluster. | string | `` | no |
| source_region | The region of the master Aurora cluster that will replicate to the created cluster. The master must be in a different region. Leave this parameter blank to create a master Aurora cluster. | string | `` | no |
| storage_encrypted | Specifies whether the DB instance is encrypted | string | `false` | no |
| subnets | Subnets for RDS Instances | list | - | yes |
| tags | Custom tags to apply to all resources. | map | `<map>` | no |
| username | The name of master user for the client DB instance. | string | `dbadmin` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_endpoint_address | The DNS address of the RDS cluster |
| cluster_endpoint_port | The port of the RDS cluster |
| cluster_endpoint_reader | A read-only endpoint for the Aurora cluster |
| cluster_id | Since terraform will build across all modules synchronously, read replicas could potentially be created after the master cluster, but before the master nodes.  To prevent this, we placed a dependency on the output, preventing the replica module from learning the master cluster ID until all nodes have built successfully. |
| db_instance | The DB instance identifier |
| monitoring_role | The IAM role used for Enhanced Monitoring |
| option_group | The Option Group used by the DB Instance |
| parameter_group | The Parameter Group used by the DB Instance |
| subnet_group | The DB Subnet Group used by the DB Instance |

