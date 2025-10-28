terraform {
  backend "s3" {
    bucket = "mycrud-terraform-tf"
    key    = "mycrud.tfsate"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "my-ec2-key"  # Change to your desired key name
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.ec2_key.private_key_pem
  filename = "${path.module}/my-ec2-key.pem"
  file_permission = "0400"
}


data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_instance" "python_app" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.ec2_key_pair.key_name
  subnet_id     = data.aws_subnets.default.ids[0]
  user_data = <<-EOF
              #!/bin/bash
              
              yum update -y
              yum install -y python3 git
              yum install -y python3-pip
              
             
              pip3 install fastapi uvicorn sqlalchemy pydantic psycopg2-binary

              # Clone your app repo (replace with your repo)
              git clone https://github.com/amartingu72/mycrud.git /home/ec2-user/app
              
              cd /home/ec2-user/app
              # Run the app (adjust as needed)
              nohup uvicorn main:app --reload --host 0.0.0.0 --port 8000 &
              EOF

  tags = {
    Name = "MyCRUDAppInstance"
  }

  vpc_security_group_ids = [aws_security_group.python_app_sg.id]
}


resource "aws_instance" "test_app" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.ec2_key_pair.key_name
  subnet_id     = data.aws_subnets.default.ids[0]
  
  tags = {
    Name = "MyTestAppInstance"
  }

  vpc_security_group_ids = [aws_security_group.python_app_sg.id]
}

resource "aws_db_subnet_group" "main" {
  name       = "main-subnet-group"
  subnet_ids = [data.aws_subnets.default.ids[1], data.aws_subnets.default.ids[2]]
  tags = {
    Name = "Main subnet group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier        = "my-postgres-db"
  engine            = "postgres"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name              = "mycruddb"
  username          = "dbuser"
  password          = "alberto123"
  publicly_accessible     = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
}



resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow Postgres access from EC2"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.python_app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "python_app_sg" {
  name        = "python_app_sg"
  description = "Allow HTTP and SSH"
  vpc_id      = data.aws_vpc.default.id
  ingress {  
    from_port   = 22
    to_port     = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
