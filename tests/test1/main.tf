provider "aws" {
  version = "~> 1.2"
  region  = "us-west-2"
}

resource "random_string" "password" {
  length      = 16
  special     = false
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

module "vpc" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//?ref=master"

  vpc_name = "Aurora-Test1VPC"
}

module "aurora_master" {
  source = "../../module"

  subnets             = "${module.vpc.private_subnets}"
  security_groups     = ["${module.vpc.default_sg}"]
  name                = "test-aurora-master"
  engine              = "aurora"
  instance_class      = "db.t2.medium"
  storage_encrypted   = true
  binlog_format       = "MIXED"
  password            = "${random_string.password.result}"
  skip_final_snapshot = true
}
