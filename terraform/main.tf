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
resource "aws_s3_bucket" "app_bucket" {
  bucket = "mycrud-bucket"
}

resource "aws_s3_object" "app_zip" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "app-v5.zip"
  source = "app-v5.zip" # Path to your zipped Python API
}



resource "aws_iam_role" "eb_role" {
  name = "elasticbeanstalk-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "eb_instance_profile" {
  name = "elasticbeanstalk-ec2-instance-profile"
  role = aws_iam_role.eb_role.name
}


resource "aws_iam_role_policy_attachment" "eb_web_tier" {
  role       = aws_iam_role.eb_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}



resource "aws_elastic_beanstalk_application_version" "app_version" {
  application = aws_elastic_beanstalk_application.app.name
  name = "v5"
  bucket        = aws_s3_bucket.app_bucket.id
  key           = aws_s3_object.app_zip.key
}


resource "aws_elastic_beanstalk_application" "app" {
  name        = "mycrud"
  description = "MyCRUD Application"
}

resource "aws_elastic_beanstalk_environment" "env" {
  name                = "development"
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.7.5 running Python 3.9"
  version_label = aws_elastic_beanstalk_application_version.app_version.name
  
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance_profile.name
  }


  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_HOST"
    value     = aws_db_instance.postgres.address
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_NAME"
    value     = aws_db_instance.postgres.db_name
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_USER"
    value     = aws_db_instance.postgres.username
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_PASSWORD"
    value     = aws_db_instance.postgres.password
  }
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
  ingress {  
    from_port   = 8000
    to_port     = 8000
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




