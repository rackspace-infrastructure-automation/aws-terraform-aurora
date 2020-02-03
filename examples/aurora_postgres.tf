terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  version = "~> 2.1"
  region  = "us-east-1"
}

provider "aws" {
  region = "us-west-2"
  alias  = "oregon"
}

data "aws_kms_secrets" "rds_credentials" {
  secret {
    name    = "password"
    payload = "AQICAHj9P8B8y7UnmuH+/93CxzvYyt+la85NUwzunlBhHYQwSAG+eG8tr978ncilIYv5lj1OAAAAaDBmBgkqhkiG9w0BBwagWTBXAgEAMFIGCSqGSIb3DQEHATAeBglghkgBZQMEAS4wEQQMoasNhkaRwpAX9sglAgEQgCVOmIaSSj/tJgEE5BLBBkq6FYjYcUm6Dd09rGPFdLBihGLCrx5H"
  }
}

module "vpc" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//?ref=v0.12.0"

  vpc_name = "Test1VPC"
}

module "aurora_postgresql_master" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-aurora//?ref=v0.12.0"

  ##################
  # Required Configuration
  ##################

  subnets           = "${module.vpc.private_subnets}"
  security_groups   = ["${module.vpc.default_sg}"]
  name              = "sample-aurora-postgresql-master"
  engine            = "aurora-postgresql"
  instance_class    = "db.r4.large"
  storage_encrypted = true
  password          = "${data.aws_kms_secrets.rds_credentials.plaintext["password"]}"

  ##################
  # VPC Configuration
  ##################

  # existing_subnet_group = "some-subnet-group-name"

  ##################
  # Backups and Maintenance
  ##################

  # maintenance_window      = "Sun:07:00-Sun:08:00"
  # backup_retention_period = 35
  # backup_window           = "05:00-06:00"
  # db_snapshot_arn         = "some-cluster-snapshot-arn"

  ##################
  # Basic RDS
  ##################

  # dbname         = "mydb"
  # engine_version = "9.6.8"
  # port           = "5432"
  # replica_instances                        = 2
  # instance_availability_zone_list          = ["us-west-2a", "us-west-2b", "us-west-2a"]

  ##################
  # RDS Advanced
  ##################

  # publicly_accessible                   = false
  # binlog_format                         = "OFF"
  # auto_minor_version_upgrade            = true
  # family                                = "aurora-postgresql9.6"
  # replica_instances                     = 1
  # storage_encrypted                     = false
  # kms_key_id                            = "some-kms-key-id"
  # parameters                            = []
  # existing_parameter_group_name         = "some-parameter-group-name"
  # cluster_parameters                    = []
  # existing_cluster_parameter_group_name = "some-parameter-group-name"
  # options                               = []
  # existing_option_group_name            = "some-option-group-name"

  ##################
  # RDS Monitoring
  ##################

  # notification_topic              = "arn:aws:sns:<region>:<account>:some-topic"
  # alarm_write_iops_limit          = 100000
  # alarm_read_iops_limit           = 100000
  # alarm_cpu_limit                 = 60
  # rackspace_alarms_enabled        = false
  # monitoring_interval             = 0
  # existing_monitoring_role_arn    = ""
  # cloudwatch_logs_exports         = []
  # performance_insights_enable     = false
  # performance_insights_kms_key_id = ""

  ##################
  # Authentication information
  ##################

  # username = "dbadmin"

  ##################
  # Other parameters
  ##################

  # environment = "Production"

  # tags = {
  #   SomeTag = "SomeValue"
  # }
}
