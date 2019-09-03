variable region {
  description = "AWS region where the reources are deployed"
  default     = "ap-southeast-2"
}

variable name {
  description = "The name of the service"
  default     = "mattermost"
}

variable tags {}

# Networking

variable vpc_id {
  description = "VPC where everything must be!"
}


# RDS

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
  default     = "db.t3.small"
}
