variable "aws_region" {
  description = "Region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "localstack_endpoint" {
  description = "Endpoint serving the AWS APIs"
  type        = string
  default     = "http://localhost:4566"
}

variable "project" {
  description = "Project name, used as a prefix for every resource"
  type        = string
  default     = "campus-cloud"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.11.0/24"
}

variable "availability_zone" {
  description = "AZ the subnets are created in"
  type        = string
  default     = "ap-south-1a"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_ami" {
  description = "AMI id for the EC2 instance (LocalStack accepts any well-formed id)"
  type        = string
  default     = "ami-0c55b159cbfafe1f0"
}

variable "allowed_http_cidr" {
  description = "CIDR allowed to reach HTTP on the web instance"
  type        = string
  default     = "0.0.0.0/0"
}
