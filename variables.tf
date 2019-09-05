variable region {
  description = "AWS region where the reources are deployed"
  default     = "ap-southeast-2"
}

variable name {
  description = "The name of the service"
  default     = "mattermost"
}

variable tags {}

#-------------------------------------
# Networking
#-------------------------------------

variable vpc_id {
  description = "VPC where everything must be!"
}

variable private_subnet_ids {
  description = "Private subnets within which to deploy internal resources."
  type        = "list"
}

variable public_subnet_ids {
  description = "Public subnets within which to deploy internet facing resources."
  type        = "list"
}

#--------------------------------------
# ECS - APP
#--------------------------------------
variable container_port {
  description = ""
  default     = 8000
}

variable http_port {
  description = "HTTP"
  default     = 80
}

variable https_port {
  description = "HTTPS"
  default     = 443
}

variable certificate_arn {
  description = "SSL certificate"
  default     = ""
}

variable cpu {
  description = "CPU quota allocated to container."
  default     = 512
}

variable memory {
  description = "Memory allocated to container."
  default     = 1024
}

variable log_prefix {
  default = "/"
}
#--------------------------------------
# RDS
#--------------------------------------

variable "db_name" {
  description = "Database name."
}

variable db_port {
  description = "Database Port."
  default     = "5432"
}

variable db_username {}

variable db_password {}

variable db_instance_type {
  description = "Type of database server."
  default     = "db.t3.medium"
}

variable aurora_engine {
  default = "aurora-postgresql"
}
