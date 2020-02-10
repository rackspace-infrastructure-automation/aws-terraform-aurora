terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region  = "us-east-1"
  version = "~> 2.1"
}

provider "aws" {
  alias  = "oregon"
  region = "us-west-2"
}

data "aws_kms_secrets" "rds_credentials" {
  secret {
    name    = "password"
    payload = "AQICAHj9P8B8y7UnmuH+/93CxzvYyt+la85NUwzunlBhHYQwSAG+eG8tr978ncilIYv5lj1OAAAAaDBmBgkqhkiG9w0BBwagWTBXAgEAMFIGCSqGSIb3DQEHATAeBglghkgBZQMEAS4wEQQMoasNhkaRwpAX9sglAgEQgCVOmIaSSj/tJgEE5BLBBkq6FYjYcUm6Dd09rGPFdLBihGLCrx5H"
  }
}

module "vpc" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//?ref=v0.12.0"

  name = "Test1VPC"
}

module "aurora_postgresql_master" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-aurora//?ref=v0.12.1"

  ##################
  # Required Configuration
  ##################

  engine            = "aurora-postgresql"
  instance_class    = "db.r4.large"
  name              = "sample-aurora-postgresql-master"
  password          = data.aws_kms_secrets.rds_credentials.plaintext["password"]
  security_groups   = [module.vpc.default_sg]
  storage_encrypted = true
  subnets           = module.vpc.private_subnets

  ##################
  # VPC Configuration
  ##################

  # existing_subnet_group = "some-subnet-group-name"

  ##################
  # Backups and Maintenance
  ##################

  # backup_retention_period = 35
  # backup_window           = "05:00-06:00"
  # db_snapshot_arn         = "some-cluster-snapshot-arn"
  # maintenance_window      = "Sun:07:00-Sun:08:00"

  ##################
  # Basic RDS
  ##################

  # dbname         = "mydb"
  # engine_version = "9.6.8"
  # instance_availability_zone_list          = ["us-west-2a", "us-west-2b", "us-west-2a"]
  # port           = "5432"
  # replica_instances                        = 2

  ##################
  # RDS Advanced
  ##################

  # auto_minor_version_upgrade            = true
  # binlog_format                         = "OFF"
  # cluster_parameters                    = []
  # existing_cluster_parameter_group_name = "some-parameter-group-name"
  # existing_option_group_name            = "some-option-group-name"
  # existing_parameter_group_name         = "some-parameter-group-name"
  # family                                = "aurora-postgresql9.6"
  # kms_key_id                            = "some-kms-key-id"
  # replica_instances                     = 1
  # options                               = []
  # parameters                            = []
  # publicly_accessible                   = false
  # storage_encrypted                     = false

  ##################
  # RDS Monitoring
  ##################

  # alarm_cpu_limit                 = 60
  # alarm_read_iops_limit           = 100000
  # alarm_write_iops_limit          = 100000
  # cloudwatch_logs_exports         = []
  # existing_monitoring_role_arn    = ""
  # monitoring_interval             = 0
  # notification_topic              = "arn:aws:sns:<region>:<account>:some-topic"
  # performance_insights_enable     = false
  # performance_insights_kms_key_id = ""
  # rackspace_alarms_enabled        = false

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

