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
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//"

  vpc_name = "Aurora-Test1VPC"
}

module "aurora_master" {
  source = "../../module"

  subnets             = "${module.vpc.private_subnets}"
  security_groups     = ["${module.vpc.default_sg}"]
  name                = "test-aurora-master"               #  Required
  engine              = "aurora"                           #  Required
  instance_class      = "db.t2.medium"                     #  Required
  storage_encrypted   = true                               #  Parameter defaults to false, but enabled for Cross Region Replication example
  binlog_format       = "MIXED"                            # Parameter needed to enable replication
  password            = "${random_string.password.result}" #  Required
  skip_final_snapshot = true
}
