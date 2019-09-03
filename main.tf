
#--------------------------------------------------------------
# RDS - Amazon Aurora Compatible with Postgres
#--------------------------------------------------------------
resource aws_rds_cluster "rds" {
  cluster_identifier  = "mattermost-db"
  engine              = "aurora-postgresql"
  database_name       = "mattermost"
  master_username     = "${var.db_username}"
  master_password     = "${var.db_password}"
  storage_encrypted   = true
  skip_final_snapshot = true
  port                = "${var.db_port}"

  tags = "${var.tags}"
}
