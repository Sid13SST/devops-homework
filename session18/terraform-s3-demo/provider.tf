terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# This project runs against LocalStack, an AWS API emulator running in Docker.
# Every Terraform command below is genuinely executed - the API calls are real
# AWS SDK calls, they are just served locally instead of by Amazon, so the demo
# costs nothing and needs no cloud credentials.
provider "aws" {
  region = var.aws_region

  # LocalStack accepts any credentials
  access_key = "test"
  secret_key = "test"

  # skip the calls that only make sense against the real AWS endpoints
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3  = var.localstack_endpoint
    iam = var.localstack_endpoint
    ec2 = var.localstack_endpoint
    sts = var.localstack_endpoint
  }
}
