output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  value = aws_db_instance.postgres.address
}

output "rds_port" {
  value = aws_db_instance.postgres.port
}

output "rds_database_name" {
  value = aws_db_instance.postgres.db_name
}

output "rds_username" {
  value = aws_db_instance.postgres.username
}

output "rds_multi_az" {
  value = aws_db_instance.postgres.multi_az
}
