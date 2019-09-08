terraform {
  backend "s3" {
    bucket = "kb-state-files"
    key    = "maina/mattermost"
    region = "ap-southeast-2"
  }
}

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

module vpc {
  source = "git@github.com:onsabimana/aws-terraform-modules.git//vpc?ref=master"

  vpc_cidr = "10.162.0.0/16"

  private_subnets_cidr = ["10.162.0.0/24", "10.162.1.0/24"]
  public_subnets_cidr  = ["10.162.10.0/24", "10.162.11.0/24"]

  availability_zones = ["ap-southeast-2a", "ap-southeast-2b"]

  tags = "${local.tags}"
}

module mattermost {
  source = "git@github.com:onsabimana/aws-terraform-modules.git//mattermost?ref=master"

  # general
  region = "${var.region}"

  # vpc
  vpc_id             = "${module.vpc.vpc_id}"
  private_subnet_ids = "${module.vpc.private_subnet_ids}"
  public_subnet_ids  = "${module.vpc.public_subnet_ids}"

  # safe internet browsing
  certificate_arn = "${aws_acm_certificate_validation.star.certificate_arn}"


  # db
  db_name     = "mattermost"
  db_username = "mattermost"
  db_password = "pAssw0rd"

  tags = "${local.tags}"
}

#--------------------------------------------------------------
# Route 53 - Subdomain mattermost to hosted domain name
#--------------------------------------------------------------

data aws_route53_zone "host" {
  name = "twofifty.io"
}

resource aws_route53_record "mattermost" {
  zone_id = "${data.aws_route53_zone.host.zone_id}"
  name    = "mattermost"
  type    = "A"

  alias {
    name                   = "${module.mattermost.alb_dns_name}"
    zone_id                = "${module.mattermost.alb_zone_id}"
    evaluate_target_health = true
  }
}

#--------------------------------------------------------------
# Domain ACM certificate
#--------------------------------------------------------------
resource aws_acm_certificate "star" {
  domain_name       = "*.twofifty.io"
  validation_method = "DNS"

  tags = "${local.tags}"
}

resource aws_route53_record "star_acm_validation" {
  zone_id = "${data.aws_route53_zone.host.zone_id}"
  name    = "${aws_acm_certificate.star.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.star.domain_validation_options.0.resource_record_type}"
  ttl     = "300"

  # Strip the trailing dot
  records = ["${replace(aws_acm_certificate.star.domain_validation_options.0.resource_record_value, "/\\.$/", "")}"]
}

resource aws_acm_certificate_validation "star" {
  certificate_arn         = "${aws_acm_certificate.star.arn}"
  validation_record_fqdns = ["${aws_route53_record.star_acm_validation.fqdn}"]
}
