terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  version = ">= 2.1.0"
  region  = "us-west-2"
}

provider "random" {
  version = "~> 2.0"
}

resource "random_string" "password" {
  length      = 16
  special     = false
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

resource "random_string" "name_rstring" {
  length  = 6
  special = false
  number  = false
  upper   = false
}

module "vpc" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//?ref=v0.12.0"

  name = "${random_string.name_rstring.result}-Aurora-Test1VPC"
}

module "aurora_master" {
  source = "../../module"

  binlog_format       = "MIXED"
  engine              = "aurora"
  instance_class      = "db.t2.medium"
  monitoring_interval = 10
  name                = "${random_string.name_rstring.result}-test-aurora-1"
  password            = random_string.password.result
  replica_instances   = 2
  security_groups     = [module.vpc.default_sg]
  skip_final_snapshot = true
  storage_encrypted   = true
  subnets             = module.vpc.private_subnets
}

module "aurora_master_with_replicas" {
  source = "../../module"

  binlog_format = "MIXED"
  engine        = "aurora"

  instance_availability_zone_list = [
    "us-west-2a",
    "us-west-2b",
    "us-west-2a",
  ]

  instance_class      = "db.t2.medium"
  name                = "${random_string.name_rstring.result}-test-aurora-2"
  password            = random_string.password.result
  replica_instances   = 2
  security_groups     = [module.vpc.default_sg]
  skip_final_snapshot = true
  storage_encrypted   = true
  subnets             = module.vpc.private_subnets
}

module "aurora_postgres" {
  source = "../../module"

  engine              = "aurora-postgresql"
  engine_version      = "11.4"
  instance_class      = "db.t3.medium"
  name                = "${random_string.name_rstring.result}-test-aurora-3"
  password            = random_string.password.result
  security_groups     = [module.vpc.default_sg]
  skip_final_snapshot = true
  storage_encrypted   = true
  subnets             = module.vpc.private_subnets
}

