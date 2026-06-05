resource "aws_db_subnet_group" "cloudopshub" {
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id
}

resource "aws_security_group" "rds" {
  name   = "${var.cluster_name}-rds-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier              = "${var.cluster_name}-postgres"
  engine                  = "postgres"
  engine_version          = "15"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "cloudopshub"
  username                = "cloudopshub"
  password                = var.db_password
  multi_az                = true
  db_subnet_group_name    = aws_db_subnet_group.cloudopshub.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  backup_retention_period = 7
  skip_final_snapshot     = false
}

