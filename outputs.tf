output role_name {
  description = "ECS task role name."
  value       = "${aws_iam_role.app.name}"
}

output role_arn {
  description = "ECS task role arn."
  value       = "${aws_iam_role.app.arn}"
}

output log_group_name {
  description = "ECS task log group name."
  value       = "${aws_cloudwatch_log_group.app.name}"
}

output alb_arn {
  description = "We facing load balancer arn"
  value       = "${aws_lb.web.arn}"
}

output alb_dns_name {
  description = "Load balancer dns name."
  value       = "${aws_lb.web.dns_name}"
}

output alb_zone_id {
  description = "Load balancer zone Id."
  value       = "${aws_lb.web.zone_id}"
}
