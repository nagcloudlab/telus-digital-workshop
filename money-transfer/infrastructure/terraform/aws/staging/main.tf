terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = "staging"
      Project     = "money-transfer"
      ManagedBy   = "terraform"
    }
  }
}

# Data source for latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for existing VPC
data "aws_vpc" "existing" {
  id = var.vpc_id
}

# Data source for existing subnets (get public subnets)
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Security Group for EC2
resource "aws_security_group" "ec2" {
  name        = "money-transfer-ec2-sg"
  description = "Security group for Money Transfer EC2 instance"
  vpc_id      = data.aws_vpc.existing.id
  
  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }
  
  # Application port
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Application access"
  }
  
  # HTTP (if needed)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }
  
  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "money-transfer-ec2-sg"
  }
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "money-transfer-ec2-role"
  
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

# Attach policy to allow EC2 to access S3
resource "aws_iam_role_policy_attachment" "ec2_s3" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "money-transfer-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "money-transfer-key"
  public_key = var.ssh_public_key
}

# User Data Script to install Java 17 and setup application
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Log everything
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    
    echo "Starting setup at $(date)"
    
    # Update system
    apt-get update
    apt-get upgrade -y
    
    # Install Java 17
    echo "Installing Java 17..."
    apt-get install -y openjdk-17-jdk
    
    # Verify Java installation
    java -version
    echo "Java installed successfully"
    
    # Create application directory
    mkdir -p /opt/money-transfer
    cd /opt/money-transfer
    
    # Create application user
    useradd -r -s /bin/false money-transfer || true
    
    # Create systemd service
    cat > /etc/systemd/system/money-transfer.service <<SERVICE
    [Unit]
    Description=Money Transfer Application
    After=network.target
    
    [Service]
    Type=simple
    User=money-transfer
    WorkingDirectory=/opt/money-transfer
    ExecStart=/usr/bin/java -Xmx512m -Xms256m -jar /opt/money-transfer/money-transfer.jar
    Restart=always
    RestartSec=10
    StandardOutput=journal
    StandardError=journal
    SyslogIdentifier=money-transfer
    
    [Install]
    WantedBy=multi-user.target
    SERVICE
    
    # Set permissions
    chown -R money-transfer:money-transfer /opt/money-transfer
    
    # Enable service (will start when JAR is deployed)
    systemctl daemon-reload
    systemctl enable money-transfer
    
    echo "Setup complete at $(date)"
    echo "Ready for application deployment!"
  EOF
}

# EC2 Instance
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = data.aws_subnets.public.ids[0]
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  
  associate_public_ip_address = true
  
  user_data = local.user_data
  
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  
  tags = {
    Name = "money-transfer-app"
  }
}

# Elastic IP for EC2
resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id
  
  tags = {
    Name = "money-transfer-eip"
  }
}