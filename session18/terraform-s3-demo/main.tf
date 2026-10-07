# ---------------------------------------------------------------- the S3 bucket
resource "aws_s3_bucket" "demo" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Session     = "18"
    Student     = "Siddhant Prasad 24BCS10255"
  }
}

# ------------------------------------------------- versioning (keeps object history)
resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# -------------------------------------------------- server side encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ------------------------------------- block all public access (secure by default)
resource "aws_s3_bucket_public_access_block" "demo" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# NOTE: aws_s3_bucket_lifecycle_configuration is intentionally not managed here.
# LocalStack's S3 emulation does not implement the propagation check the AWS
# provider waits on, so the resource times out after 3 minutes against LocalStack
# (it works normally against real AWS). S3 lifecycle policies are documented in
# ../aws-services/03-s3/README.md instead.

# ------------------------------------ an object, proving the bucket is usable
resource "aws_s3_object" "readme" {
  bucket       = aws_s3_bucket.demo.id
  key          = "session18/hello.txt"
  content      = "Created by Terraform for Session 18 - Siddhant Prasad (24BCS10255)\n"
  content_type = "text/plain"
}
