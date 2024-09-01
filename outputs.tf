output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Public Subnets"
  value       = aws_subnet.public_subnet
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = aws_ecs_cluster.main.name
}

output "ecr_repository_url" {
  description = "ECR Repository URL"
  value       = aws_ecr_repository.main.repository_url
}

output "key_pair_private_key" {
  description = "Private key for the EC2 instances"
  value       = tls_private_key.ecs_key_pair.private_key_pem
  sensitive   = true
}

output "key_pair_name" {
  description = "Name of the generated key pair"
  value       = aws_key_pair.ecs_key_pair.key_name
}