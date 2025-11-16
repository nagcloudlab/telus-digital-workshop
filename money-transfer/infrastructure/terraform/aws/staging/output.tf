output "ec2_public_ip" {
  description = "Public IP address of EC2 instance"
  value       = aws_eip.app.public_ip
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_eip.app.public_ip}:8080"
}

output "h2_console_url" {
  description = "URL to access H2 database console"
  value       = "http://${aws_eip.app.public_ip}:8080/h2-console"
}

output "ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i money-transfer-key.pem ubuntu@${aws_eip.app.public_ip}"
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "vpc_id" {
  description = "VPC ID being used"
  value       = data.aws_vpc.existing.id
}

output "subnet_id" {
  description = "Subnet ID being used"
  value       = data.aws_subnets.public.ids[0]
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.ec2.id
}