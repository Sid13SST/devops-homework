# -------------------------------------------------- S3 bucket for application data
resource "aws_s3_bucket" "assets" {
  bucket = "${var.project}-assets-24bcs10255"

  tags = {
    Name        = "${var.project}-assets"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# This object references the VPC and the instance, which makes the dependency
# between the storage and compute parts of the stack explicit in the graph.
resource "aws_s3_object" "inventory" {
  bucket       = aws_s3_bucket.assets.id
  key          = "inventory/stack.txt"
  content_type = "text/plain"
  content      = "project=${var.project} environment=${var.environment} vpc=${aws_vpc.main.id} instance=${aws_instance.web.id} web_sg=${aws_security_group.web.id}"
}
