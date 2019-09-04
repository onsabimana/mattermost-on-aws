provider aws {
  region  = "${var.region}"
  version = "~> 2.26"
}

locals {
  tags = {
    Environment = "Development"
    Name        = "mattermost"
    Client      = "Maina"
  }
}

module "vpc" {
  source = "../../aws-terraform-modules/vpc"

  vpc_cidr = "10.162.0.0/16"

  private_subnets_cidr = ["10.162.0.0/24", "10.162.1.0/24"]
  public_subnets_cidr  = ["10.162.10.0/24", "10.162.11.0/24"]

  availability_zones = ["ap-southeast-2a", "ap-southeast-2b"]

  tags = "${local.tags}"
}
module "mattermost" {
  source = "../"

  # general
  region = "${var.region}"

  # vpc
  vpc_id             = "${module.vpc.vpc_id}"
  private_subnet_ids = "${module.vpc.private_subnet_ids}"
  public_subnet_ids  = "${module.vpc.public_subnet_ids}"


  # db
  db_name     = "mattermost"
  db_username = "mattermost"
  db_password = "pAssw0rd"

  tags = "${local.tags}"
}
