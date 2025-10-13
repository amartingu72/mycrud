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


resource "aws_instance" "python_app" {
  ami           = var.ami_id
  count         = 
  instance_type = var.instance_type
  key_name      = aws_key_pair.ec2_key_pair.key_name

  user_data = <<-EOF
              #!/bin/bash
              
              yum update -y
              yum install -y python3 git
              yum install -y python3-pip
              
              pip3 install fastapi uvicorn sqlalchemy pydantic

              # Clone your app repo (replace with your repo)
              git clone https://github.com/amartingu72/mycrud.git /home/ec2-user/app
              
              cd /home/ec2-user/app
              # Run the app (adjust as needed)
              nohup uvicorn main:app --reload --host 0.0.0.0 --port 8000 &
              EOF

  tags = {
    Name = "MycrudAppInstance-${count.index + 1}"
  }

  security_groups = [aws_security_group.python_app_sg.name]
}

resource "aws_instance" "test_app" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.ec2_key_pair.key_name

  
  tags = {
    Name = "MyTestAppInstance"
  }

  security_groups = [aws_security_group.python_app_sg.name]
}


resource "aws_security_group" "python_app_sg" {
  name        = "python_app_sg"
  description = "Allow HTTP and SSH"

  
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
    security_group_id = aws_security_group.python_app_sg.id
    from_port   = 22
    to_port     = 22
    ip_protocol    = "tcp"
    cidr_ipv4 = "0.0.0.0/0"
  }

resource "aws_vpc_security_group_ingress_rule" "allow_8000" {
    security_group_id = aws_security_group.python_app_sg.id
    from_port   = 8000
    to_port     = 8000
    ip_protocol    = "tcp"
    cidr_ipv4 = "0.0.0.0/0"
  }

resource "aws_vpc_security_group_egress_rule" "allow_all_egress" {
    security_group_id = aws_security_group.python_app_sg.id
    ip_protocol = "-1"
    cidr_ipv4 = "0.0.0.0/0"
  }
