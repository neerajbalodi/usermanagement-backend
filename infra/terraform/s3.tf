# ---------------------------------------------------------------
# Day 2: S3 bucket for user photos
#   - PRIVATE: nobody on the internet can read it directly
#   - the backend hands out temporary (pre-signed) links instead
# ---------------------------------------------------------------

# Bucket names are global across ALL AWS accounts, so add a random suffix
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "photos" {
  bucket = "${var.name_prefix}-photos-${random_id.bucket_suffix.hex}"

  # Lets "terraform destroy" delete the bucket even if photos are still in it.
  # Fine for a class; in a real project you would protect the data instead.
  force_destroy = true

  tags = { Name = "${var.name_prefix}-photos" }
}

# Block every kind of public access (the most important S3 setting)
resource "aws_s3_bucket_public_access_block" "photos" {
  bucket = aws_s3_bucket.photos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt every photo at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "photos" {
  bucket = aws_s3_bucket.photos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
