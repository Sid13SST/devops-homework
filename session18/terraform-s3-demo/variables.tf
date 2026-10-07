variable "aws_region" {
  description = "AWS region the bucket is created in"
  type        = string
  default     = "ap-south-1"
}

variable "localstack_endpoint" {
  description = "Endpoint that serves the AWS APIs (LocalStack)"
  type        = string
  default     = "http://localhost:4566"
}

variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Environment tag applied to every resource"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "enable_versioning" {
  description = "Whether to keep previous versions of every object"
  type        = bool
  default     = true
}
