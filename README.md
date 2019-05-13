# aws-terraform-aurora

This module creates an aurora RDS cluster.  The module currently supports the aurora, aurora-mysql, and aurora-postgres engines.

The module will output the required configuration files to enable client and worker node setup and configuration.

## Basic Usage

```
module "aurora_master" {
 source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-aurora//?ref=v0.0.2"

 subnets                                  = "${module.vpc.private_subnets}"
 security_groups                          = ["${module.vpc.default_sg}"]
 name                                     = "sample-aurora-master"
 engine                                   = "aurora"
 instance_class                           = "db.t2.medium"
 storage_encrypted                        = true
 binlog_format                            = "MIXED"
 password                                 = "${data.aws_kms_secrets.rds_credentials.plaintext["password"]}"
 replica_instances                        = 2
 instance_availability_zone_list          = ["us-west-2a", "us-west-2b", "us-west-2a"]
}
```

Full working references are available at [examples](examples)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| alarm\_cpu\_limit | CloudWatch CPUUtilization Threshold | string | `"60"` | no |
| alarm\_read\_io\_limit | CloudWatch Read IOPSLimit Threshold | string | `"100000"` | no |
| alarm\_write\_io\_limit | CloudWatch Write IOPSLimit Threshold | string | `"100000"` | no |
| auto\_minor\_version\_upgrade | Boolean value that indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window | string | `"true"` | no |
| backtrack\_window | The target backtrack window, in seconds.  Defaults to 1 day. Setting only affects supported versions (currently MySQL 5.6). | string | `"86400"` | no |
| backup\_retention\_period | The number of days for which automated backups are retained. Setting this parameter to a positive number enables backups. Setting this parameter to 0 disables automated backups. Compass best practice is 30 or more days. | string | `"35"` | no |
| backup\_window | The daily time range during which automated backups are created if automated backups are enabled. | string | `"05:00-06:00"` | no |
| binlog\_format | Sets the desired format. Defaults to OFF. Should be set to MIXED if this Aurora cluster will replicate to another RDS Instance or cluster. Ignored for aurora-postgresql engine | string | `"OFF"` | no |
| cluster\_parameters | List of custom cluster parameters to apply to the parameter group. | list | `<list>` | no |
| create\_internal\_records | Create an internal Route 53 record for the RDS cluster and cluster reader. Default is false. | string | `"false"` | no |
| db\_snapshot\_arn | The identifier for the DB cluster snapshot from which you want to restore. | string | `""` | no |
| dbname | The DB name to create. If omitted, no database is created initially | string | `""` | no |
| enable\_delete\_protection | If the DB instance should have deletion protection enabled. The database can't be deleted when this value is set to true. The default is false | string | `"false"` | no |
| engine | Database Engine Type.  Allowed values: aurora-mysql, aurora, aurora-postgresql | string | `"aurora-mysql"` | no |
| engine\_mode | The database engine mode. Allowed values: provisioned and global(aurora engine only). | string | `"provisioned"` | no |
| engine\_version | Database Engine Minor Version http://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_CreateDBInstance.html | string | `""` | no |
| environment | Application environment for which this network is being created. one of: ('Development', 'Integration', 'PreProduction', 'Production', 'QA', 'Staging', 'Test') | string | `"Development"` | no |
| existing\_cluster\_parameter\_group\_name | The existing cluster parameter group to use for this instance. (OPTIONAL) | string | `""` | no |
| existing\_monitoring\_role | ARN of an existing enhanced monitoring role to use for this instance. (OPTIONAL) | string | `""` | no |
| existing\_option\_group\_name | The existing option group to use for this instance. (OPTIONAL) | string | `""` | no |
| existing\_parameter\_group\_name | The existing parameter group to use for this instance. (OPTIONAL) | string | `""` | no |
| existing\_subnet\_group | The existing DB subnet group to use for this cluster (OPTIONAL) | string | `""` | no |
| family | Parameter Group Family Name (ex. aurora5.6, aurora-postgresql9.6, aurora-mysql5.7) | string | `""` | no |
| global\_cluster\_identifier | Global Cluster identifier. Property of aws_rds_global_cluster (Ignored if engine_mode is not 'global'). | string | `""` | no |
| instance\_availability\_zone\_list | List of availability zones to place each aurora instance. Availability zone assignment is by index. The first AZ in the list is assigned to the first instance,  second AZ in the list to the second instance, third AZ in the list to the third instance, etc. Also please remember that the number of AZs specified here should equal to replica_instances + 1. | list | `<list>` | no |
| instance\_class | The database instance type. | string | n/a | yes |
| internal\_record\_cluster | The full record name you would like to add as a CNAME for the cluster that matches your Hosted Zone. i.e. cluster.example.com | string | `""` | no |
| internal\_record\_cluster\_reader | The full record name you would like to add as a CNAME for the cluster reader. i.e. reader.example.com | string | `""` | no |
| internal\_zone\_id | The zone id you would like the internal records for the cluster and reader to be created in. i.e. Z2QHD5YD1WXE9M | string | `""` | no |
| kms\_key\_id | KMS Key Arn to use for storage encryption. (OPTIONAL) | string | `""` | no |
| maintenance\_window | The weekly time range (in UTC) during which system maintenance can occur. | string | `"Sun:07:00-Sun:08:00"` | no |
| monitoring\_interval | The interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance. To disable collecting Enhanced Monitoring metrics, specify 0. The default is 0. Valid Values: 0, 1, 5, 10, 15, 30, 60. | string | `"0"` | no |
| name | The name prefix to use for the resources created in this module. | string | n/a | yes |
| notification\_topic | List of SNS Topic ARNs to use for customer notifications from CloudWatch alarms. (OPTIONAL) | list | `<list>` | no |
| options | List of custom options to apply to the option group. | list | `<list>` | no |
| parameters | List of custom parameters to apply to the parameter group. | list | `<list>` | no |
| password | Password for the local administrator account. | string | n/a | yes |
| port | The port on which the DB accepts connections | string | `""` | no |
| publicly\_accessible | Boolean value that indicates whether the database instances are Internet-facing. | string | `"false"` | no |
| rackspace\_alarms\_enabled | Specifies whether non-emergency rackspace alarms will create a ticket. | string | `"false"` | no |
| rackspace\_managed | Boolean parameter controlling if instance will be fully managed by Rackspace support teams, created CloudWatch alarms that generate tickets, and utilize Rackspace managed SSM documents. | string | `"true"` | no |
| replica\_instances | The number of Aurora replica instances to create.  This can range from 0 to 15. | string | `"1"` | no |
| security\_groups | A list of EC2 security groups to assign to this resource | list | n/a | yes |
| skip\_final\_snapshot | Boolean value to control if the DB Cluster will take a final snapshot when destroyed.  This value should be set to false if a final snapshot is desired. | string | `"false"` | no |
| source\_cluster | The cluster ID of the master Aurora cluster that will replicate to the created cluster. The master must be in a different region. Leave this parameter blank to create a master Aurora cluster. | string | `""` | no |
| source\_region | The region of the master Aurora cluster that will replicate to the created cluster. The master must be in a different region. Leave this parameter blank to create a master Aurora cluster. | string | `""` | no |
| storage\_encrypted | Specifies whether the DB instance is encrypted | string | `"false"` | no |
| subnets | Subnets for RDS Instances | list | n/a | yes |
| tags | Custom tags to apply to all resources. | map | `<map>` | no |
| username | The name of master user for the client DB instance. | string | `"dbadmin"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_endpoint\_address | The DNS address of the RDS cluster |
| cluster\_endpoint\_port | The port of the RDS cluster |
| cluster\_endpoint\_reader | A read-only endpoint for the Aurora cluster |
| cluster\_id | The DB Cluster identifier |
| db\_instance | The DB instance identifier |
| monitoring\_role | The IAM role used for Enhanced Monitoring |
| option\_group | The Option Group used by the DB Instance |
| parameter\_group | The Parameter Group used by the DB Instance |
| subnet\_group | The DB Subnet Group used by the DB Instance |

