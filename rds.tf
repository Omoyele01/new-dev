resource "aws_db_subnet_group" "rds_subnets" {
  name       = "main-rds-subnet-group"
  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  tags = {
    Name = "Main RDS subnet group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier              = "main-postgres-db"
  engine                  = "postgres"
  #engine_version          = "14.7"  # ✅ More stable version
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "maindb"
  username                = var.db_username
  password                = var.db_password
  skip_final_snapshot     = true
  publicly_accessible     = false
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.rds_subnets.name

  tags = {
    Name = "main-postgres-db"
  }
}
