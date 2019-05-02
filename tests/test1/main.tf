provider "aws" {
  version = "~> 1.2"
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
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//?ref=master"

  vpc_name = "${random_string.name_rstring.result}-Aurora-Test1VPC"
}

module "aurora_master" {
  source = "../../module"

  subnets             = "${module.vpc.private_subnets}"
  security_groups     = ["${module.vpc.default_sg}"]
  name                = "${random_string.name_rstring.result}-test-aurora-1"
  engine              = "aurora"
  instance_class      = "db.t2.medium"
  storage_encrypted   = true
  binlog_format       = "MIXED"
  password            = "${random_string.password.result}"
  skip_final_snapshot = true
  replica_instances   = 2
}

module "aurora_master_with_replicas" {
  source = "../../module"

  subnets                         = "${module.vpc.private_subnets}"
  security_groups                 = ["${module.vpc.default_sg}"]
  name                            = "${random_string.name_rstring.result}-test-aurora-2"
  engine                          = "aurora"
  instance_class                  = "db.t2.medium"
  storage_encrypted               = true
  binlog_format                   = "MIXED"
  password                        = "${random_string.password.result}"
  skip_final_snapshot             = true
  replica_instances               = 2
  instance_availability_zone_list = ["us-west-2a", "us-west-2b", "us-west-2a"]
}
