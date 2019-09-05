
#--------------------------------------------------------------
# Security Groups
#--------------------------------------------------------------
resource aws_security_group "web" {
  name        = "${var.name}-web-sg"
  description = "${title(var.name)} web facing security group"
  vpc_id      = "${var.vpc_id}"
}

resource aws_security_group_rule "http_in" {
  description       = "Allow incoming http traffic from anywhere over http port."
  type              = "ingress"
  from_port         = "${var.http_port}"
  to_port           = "${var.http_port}"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.web.id}"
}

resource aws_security_group_rule "https_in" {
  description       = "Allow incoming https traffic from anywhere over https port."
  type              = "ingress"
  from_port         = "${var.https_port}"
  to_port           = "${var.https_port}"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.web.id}"
}

resource aws_security_group_rule "web_out" {
  description       = "Allow load balancer outgoing traffic."
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.web.id}"
}

resource aws_security_group "app" {
  name        = "${var.name}-app-sg"
  description = "${title(var.name)} application security group"
  vpc_id      = "${var.vpc_id}"
}

resource aws_security_group_rule "app_in" {
  description              = "Allow incoming http traffic from loadbalancer to Grafana http port."
  type                     = "ingress"
  from_port                = "${var.http_port}"
  to_port                  = "${var.container_port}"
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.web.id}"
  security_group_id        = "${aws_security_group.app.id}"
}

resource aws_security_group_rule "app_out" {
  description       = "Allow grafana application outgoing traffic."
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.app.id}"
}

#--------------------------------------------------------------
# Application Load Balancer - used as a web proxy
#--------------------------------------------------------------
resource aws_lb "web" {
  name            = "${var.name}-web-lb"
  internal        = false
  security_groups = ["${aws_security_group.web.id}"]
  subnets         = "${var.public_subnet_ids}"
  idle_timeout    = "3600"

  enable_deletion_protection = false

  tags = "${var.tags}"
}

resource random_pet "prefix" {
  length = 1
}

resource aws_lb_target_group "app" {
  name                 = "${random_pet.prefix.id}-app-tg"
  port                 = "${var.container_port}"
  protocol             = "HTTP"
  vpc_id               = "${var.vpc_id}"
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    interval            = 10
    path                = "/"
    port                = "${var.container_port}"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = "${var.tags}"
}

resource aws_lb_listener "front_end_http" {
  load_balancer_arn = "${aws_lb.web.arn}"
  port              = "${var.http_port}"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.app.arn}"
    type             = "forward"
  }
}

resource aws_lb_listener "front_end_https" {
  count = "${var.certificate_arn != "" ? 1 : 0}"

  load_balancer_arn = "${aws_lb.web.arn}"
  port              = "${var.https_port}"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = "${var.certificate_arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.app.arn}"
    type             = "forward"
  }
}

#--------------------------------------------------------------
# ECS - Basic Permissions
#--------------------------------------------------------------
data aws_iam_policy_document "ecs_assume_role" {
  statement {
    sid = "${title(var.name)}ECSAssumeRole"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource aws_iam_role "ecs_task_execution" {
  name               = "${var.name}-ecs-role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_assume_role.json}"
}

data aws_iam_policy_document "ecs_task_execution" {
  statement {
    sid    = "AllowECSToWriteLogsToCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${aws_cloudwatch_log_group.app.arn}"]
  }

  statement {
    sid    = "AllowECSToPullDockerImage"
    effect = "Allow"

    actions = [
      "ecr:*",
    ]

    resources = ["*"]
  }
}

resource aws_iam_role_policy "ecs_task_execution" {
  name   = "${title(var.name)}ECSTaskExecutionRole"
  role   = "${aws_iam_role.ecs_task_execution.name}"
  policy = "${data.aws_iam_policy_document.ecs_task_execution.json}"
}

resource aws_iam_role "app" {
  name               = "${title(var.name)}ApplicationRole"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_assume_role.json}"
}

#------------------------------------------------------------
# ECS - FARGATE App to run the mmattermost docker container
#------------------------------------------------------------
resource aws_cloudwatch_log_group "app" {
  name = "${var.name}"
}

resource aws_ecs_cluster "app" {
  name = "${var.name}"
}

locals {
  container_definitions = <<JSON
[{
  "cpu": 0,
  "image": "mattermost/mattermost-prod-app",
  "name": "${var.name}",
  "logConfiguration": {
    "logdriver": "awslogs",
    "options": {
      "awslogs-group": "${aws_cloudwatch_log_group.app.name}",
      "awslogs-region": "${var.region}",
      "awslogs-stream-prefix": "${var.log_prefix}"
    }
  },
  "essential": true,
  "portMappings": [
    {
          "hostPort": ${var.container_port},
          "containerPort": ${var.container_port},
          "protocol": "tcp"
    }
  ],
  "volumesFrom": [],
  "mountPoints": [],
  "environment": [
    {"name": "MM_USERNAME",   "value": "${var.db_username}"},
    {"name": "MM_PASSWORD",   "value": "${var.db_password}"},
    {"name": "MM_DBNAME",     "value": "${var.db_name}"},
    {"name": "DB_HOST",       "value": "${aws_rds_cluster.rds.endpoint}"},
    {"name": "DB_PORT",       "value": "${var.db_port}"}
  ]
}]
JSON
}

resource aws_ecs_task_definition "app" {
  family                   = "${var.name}"
  container_definitions    = "${local.container_definitions}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.cpu}"
  memory                   = "${var.memory}"
  task_role_arn            = "${aws_iam_role.app.arn}"
  execution_role_arn       = "${aws_iam_role.ecs_task_execution.arn}"
  network_mode             = "awsvpc"
}

resource aws_ecs_service "app" {
  name            = "${var.name}"
  cluster         = "${aws_ecs_cluster.app.name}"
  task_definition = "${aws_ecs_task_definition.app.arn}"
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = ["${aws_security_group.app.id}"]
    subnets          = "${var.private_subnet_ids}"
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.app.arn}"
    container_name   = "${var.name}"
    container_port   = "${var.container_port}"
  }
}

#--------------------------------------------------------------
# RDS - Amazon Aurora Compatible with Postgres
#--------------------------------------------------------------
resource aws_security_group "rds" {
  name_prefix = "${var.name}-rds-sg"
  description = "RDS Aurora access from internal security groups"
  vpc_id      = "${var.vpc_id}"

  tags = "${var.tags}"
}

resource aws_security_group_rule "rds_ingress" {
  description              = "Allow traffic to db port from ${title(var.name)} to RDS."
  type                     = "ingress"
  from_port                = "${var.db_port}"
  to_port                  = "${var.db_port}"
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.rds.id}"
  source_security_group_id = "${aws_security_group.app.id}"
}

resource aws_security_group_rule "rds_egress" {
  description       = "Allow traffic from RDS to the rest of the world."
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.rds.id}"
}

resource aws_db_subnet_group "rds" {
  name        = "${var.name}-db-subnet"
  description = "Subnets to launch RDS database into"
  subnet_ids  = "${var.private_subnet_ids}"

  tags = "${var.tags}"
}

resource aws_rds_cluster "rds" {
  cluster_identifier     = "${var.name}-db"
  engine                 = "${var.aurora_engine}"
  database_name          = "${var.db_name}"
  master_username        = "${var.db_username}"
  master_password        = "${var.db_password}"
  storage_encrypted      = true
  skip_final_snapshot    = true
  port                   = "${var.db_port}"
  db_subnet_group_name   = "${aws_db_subnet_group.rds.name}"
  vpc_security_group_ids = ["${aws_security_group.rds.id}"]

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }

  tags = "${var.tags}"
}

resource "aws_rds_cluster_instance" "rds" {
  cluster_identifier         = "${aws_rds_cluster.rds.id}"
  identifier                 = "${var.name}-db"
  engine                     = "${var.aurora_engine}"
  instance_class             = "${var.db_instance_type}"
  publicly_accessible        = false
  db_subnet_group_name       = "${aws_db_subnet_group.rds.name}"
  auto_minor_version_upgrade = true

  tags = "${var.tags}"

  lifecycle {
    create_before_destroy = true
  }
}
