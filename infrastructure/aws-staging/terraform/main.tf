# ==========================================
# Terraform Configuration
# ==========================================
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
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

# ==========================================
# Provider Configuration
# ==========================================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# ==========================================
# Data Sources
# ==========================================

# Get latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ==========================================
# VPC and Networking
# ==========================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ==========================================
# Security Group - WITH ALL MONITORING PORTS
# ==========================================

resource "aws_security_group" "money_transfer_sg" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for Money Transfer application and monitoring stack"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP via Nginx
  ingress {
    description = "HTTP via Nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Application port
  ingress {
    description = "Application HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana Dashboard
  ingress {
    description = "Grafana Dashboard"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus Web UI
  ingress {
    description = "Prometheus Web UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # AlertManager Web UI
  ingress {
    description = "AlertManager Web UI"
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Node Exporter Metrics
  ingress {
    description = "Node Exporter Metrics"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg"
  }
}

# ==========================================
# IAM Role for EC2
# ==========================================

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

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

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-role"
  }
}

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${var.project_name}-${var.environment}-cloudwatch-logs"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${var.project_name}-${var.environment}*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudwatch_metrics" {
  name = "${var.project_name}-${var.environment}-cloudwatch-metrics"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-profile"
  }
}

# ==========================================
# SSH Key Pair
# ==========================================

resource "aws_key_pair" "main" {
  key_name   = var.key_name
  public_key = file("~/.ssh/id_rsa.pub")

  tags = {
    Name = "${var.project_name}-${var.environment}-key"
  }
}

# ==========================================
# EC2 Instance
# ==========================================

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.money_transfer_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(file("${path.module}/user-data.sh"))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-${var.environment}-root-volume"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring = true

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Application = "money-transfer"
    Monitoring  = "enabled"
  }

  lifecycle {
    create_before_destroy = false
    ignore_changes        = [ami]
  }
}

# ==========================================
# Elastic IP
# ==========================================

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# ==========================================
# CloudWatch Resources
# ==========================================

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs"
    Application = "money-transfer"
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors ec2 cpu utilization"

  dimensions = {
    InstanceId = aws_instance.app.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cpu-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "status_check" {
  alarm_name          = "${var.project_name}-${var.environment}-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "This metric monitors ec2 status checks"

  dimensions = {
    InstanceId = aws_instance.app.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-status-alarm"
  }
}

# ==========================================
# Outputs
# ==========================================

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "Public IP address (Elastic IP)"
  value       = aws_eip.app.public_ip
}

output "instance_private_ip" {
  description = "Private IP address"
  value       = aws_instance.app.private_ip
}

output "ssh_command" {
  description = "SSH command to connect to instance"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.app.public_ip}"
}

output "application_url" {
  description = "Application URL"
  value       = "http://${aws_eip.app.public_ip}:8080"
}

output "health_check_url" {
  description = "Health check URL"
  value       = "http://${aws_eip.app.public_ip}:8080/actuator/health"
}

output "nginx_url" {
  description = "Nginx proxy URL"
  value       = "http://${aws_eip.app.public_ip}"
}

output "monitoring_urls" {
  description = "Monitoring stack URLs"
  value = {
    grafana       = "http://${aws_eip.app.public_ip}:3000"
    prometheus    = "http://${aws_eip.app.public_ip}:9090"
    alertmanager  = "http://${aws_eip.app.public_ip}:9093"
    node_exporter = "http://${aws_eip.app.public_ip}:9100/metrics"
  }
}

output "all_urls" {
  description = "All service URLs in one place"
  value = {
    application = {
      main   = "http://${aws_eip.app.public_ip}:8080"
      health = "http://${aws_eip.app.public_ip}:8080/actuator/health"
      nginx  = "http://${aws_eip.app.public_ip}"
    }
    monitoring = {
      grafana       = "http://${aws_eip.app.public_ip}:3000 (admin/admin123)"
      prometheus    = "http://${aws_eip.app.public_ip}:9090"
      alertmanager  = "http://${aws_eip.app.public_ip}:9093"
      node_exporter = "http://${aws_eip.app.public_ip}:9100/metrics"
    }
  }
}

output "useful_commands" {
  description = "Useful commands for managing the instance"
  value = {
    ssh               = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.app.public_ip}"
    view_setup_log    = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.app.public_ip} 'tail -100 /var/log/user-data.log'"
    view_app_logs     = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.app.public_ip} 'docker logs money-transfer-staging -f'"
    check_monitoring  = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.app.public_ip} 'cd ~/monitoring && docker-compose ps'"
    monitoring_logs   = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.app.public_ip} 'cd ~/monitoring && docker-compose logs -f'"
    instance_info     = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.app.public_ip} 'cat /opt/money-transfer/instance-info.txt'"
  }
}