# ==========================================
# Project Configuration Variables
# ==========================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "money-transfer"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

# ==========================================
# AWS Configuration Variables
# ==========================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

# ==========================================
# EC2 Configuration Variables
# ==========================================

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "money-transfer-staging-key"
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
  default     = ""
}

# ==========================================
# Application Configuration Variables
# ==========================================

variable "app_version" {
  description = "Application version"
  type        = string
  default     = "latest"
}

# ==========================================
# Network Configuration Variables
# ==========================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# ==========================================
# Tags Configuration
# ==========================================

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "money-transfer"
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}