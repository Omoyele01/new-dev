# PROVIDER
provider "aws" {
  region = "us-east-1"
}

# # STATE STORAGE - S3 Bucket for Terraform state
# resource "aws_s3_bucket" "tf_state" {
#   bucket = "vgs-s3"

#   tags = {
#     Name = "Terraform State"
#   }
# }

# resource "aws_s3_bucket_versioning" "versioning" {
#   bucket = aws_s3_bucket.tf_state.id

#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_public_access_block" "public_access" {
#   bucket = aws_s3_bucket.tf_state.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# # DynamoDB table for Terraform state locking
# resource "aws_dynamodb_table" "tf_lock" {
#   name         = "terraform-locks"
#   hash_key     = "LockID"
#   billing_mode = "PAY_PER_REQUEST"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }
# }

# STEP 1: VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# STEP 2: SUBNETS
# Public subnets with public IP mapping
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}

# Private subnets without public IP mapping
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet-2"
  }
}

# STEP 3: INTERNET GATEWAY
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# STEP 4B: NAT Gateway for Private Subnets

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "nat-eip"
  }
}

# NAT Gateway in Public Subnet 1
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "nat-gw"
  }

  depends_on = [aws_internet_gateway.igw]
}

# STEP 5B: Private Route Table with default route to NAT Gateway
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private_1_assoc" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2_assoc" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

# STEP 4: PUBLIC ROUTE TABLE
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# STEP 5: Associate public subnets to route table
resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# STEP 6: SECURITY GROUPS & EC2 INSTANCES

# Bastion Security Group - SSH only from specific IP
resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH from local machine"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["77.102.208.31/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Private EC2 Security Group - SSH from bastion only
resource "aws_security_group" "private_ec2_sg" {
  name   = "private-ec2-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-ec2-sg"
  }
}

# Bastion Host EC2 Instance - public subnet, public IP assigned
resource "aws_instance" "bastion" {
  ami                         = "ami-0871b7e0b83ae16c4"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_1.id
  associate_public_ip_address = true
  key_name                    = "yele-key-pair"
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "bastion-host"
  }
}

# Private EC2 Instance - private subnet, no public IP
resource "aws_instance" "private_ec2" {
  ami                         = "ami-0871b7e0b83ae16c4"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_1.id
  associate_public_ip_address = false
  key_name                    = "yele-key-pair"
  vpc_security_group_ids      = [aws_security_group.private_ec2_sg.id]

  tags = {
    Name = "private-ec2"
  }
}
