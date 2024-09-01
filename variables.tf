variable "region" {
  description = "AWS Region"
  default     = "us-east-1"
}
variable "profile" {
    description = "AWS profile to use"
    default     = "default"
} 

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnets"
  type = list(string)
  default     = ["10.0.1.0/24","10.0.2.0/24"]
}
variable "public_subnet_azs" {
  description = "azs for the public subnets"
  type = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "ecs_cluster_name" {
  description = "Name of the ECS Cluster"
  default     = "theam"
}

variable "ecs_instance_type" {
  description = "EC2 instance type for ECS (t2.micro is within free tier)"
  default     = "t3.micro"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  default     = "theam"
}

variable "key_pair_name" {
  description = "Name of the SSH key pair to use for the ECS instances"
  default     = "theam-keypair"
}

variable "ec2_root_volume_size" {
  description = "Size of the root EBS volume (in GB)"
  default     = 30
}
