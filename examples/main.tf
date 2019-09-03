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

data aws_vpc "default" {
  default = true
}

module "mattermost" {
  source = "../"

  # general
  region = "${var.region}"

  # vpc
  vpc_id          = "${data.aws_vpc.default.id}"

  # db
  db_name     = "mattermost"
  db_username = "admin"
  db_password = "admin1234"

  tags = "${local.tags}"
}
