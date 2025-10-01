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

resource "aws_instance" "python_app" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 git
              pip install fastapi uvicorn sqlalchemy pydantic

              # Clone your app repo (replace with your repo)
              git clone https://github.com/amartingu72/mycrud.git /home/ec2-user/app
              cd /home/ec2-user/app

              # Run the app (adjust as needed)
              nohup uvicorn main:app --reload &
              EOF

  tags = {
    Name = "MycrudAppInstance"
  }

  security_groups = [aws_security_group.python_app_sg.name]
}

resource "aws_security_group" "python_app_sg" {
  name        = "python_app_sg"
  description = "Allow HTTP and SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
