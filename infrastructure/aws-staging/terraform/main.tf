# AWS Staging Environment for Money Transfer App
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "money-transfer-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "MoneyTransfer"
      Environment = "Staging"
      ManagedBy   = "Terraform"
      Workshop    = "CICD-ShiftLeft"
    }
  }
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Security Group
resource "aws_security_group" "staging_app" {
  name_prefix = "money-transfer-staging-"
  description = "Security group for Money Transfer staging"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Application"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "money-transfer-staging-sg"
  }
}

# IAM Role
resource "aws_iam_role" "staging_ec2_role" {
  name_prefix = "money-transfer-staging-ec2-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.staging_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.staging_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "staging_profile" {
  name_prefix = "money-transfer-staging-"
  role        = aws_iam_role.staging_ec2_role.name
}

# Key Pair
resource "aws_key_pair" "staging_key" {
  key_name_prefix = "money-transfer-staging-"
  public_key      = var.ssh_public_key
}

# EC2 Instance
resource "aws_instance" "staging_app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.staging_key.key_name
  vpc_security_group_ids = [aws_security_group.staging_app.id]
  iam_instance_profile   = aws_iam_instance_profile.staging_profile.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    app_version = var.app_version
    environment = "staging"
  }))

  monitoring = true

  tags = {
    Name = "money-transfer-staging"
  }
}

# Elastic IP
resource "aws_eip" "staging_eip" {
  instance = aws_instance.staging_app.id
  domain   = "vpc"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "staging_logs" {
  name              = "/aws/ec2/money-transfer/staging"
  retention_in_days = 7
}

# Outputs
output "instance_id" {
  value = aws_instance.staging_app.id
}

output "instance_public_ip" {
  value = aws_eip.staging_eip.public_ip
}

output "application_url" {
  value = "http://${aws_eip.staging_eip.public_ip}:8080"
}

output "health_check_url" {
  value = "http://${aws_eip.staging_eip.public_ip}:8080/actuator/health"
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.staging_eip.public_ip}"
}
