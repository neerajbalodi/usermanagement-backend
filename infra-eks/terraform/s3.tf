# ---------------------------------------------------------------
# S3 bucket for user photos (same as Day 2): private + encrypted
# ---------------------------------------------------------------
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "photos" {
  bucket        = "${var.name_prefix}-photos-${random_id.bucket_suffix.hex}"
  force_destroy = true # class setting: destroy even if photos are inside
}

resource "aws_s3_bucket_public_access_block" "photos" {
  bucket = aws_s3_bucket.photos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "photos" {
  bucket = aws_s3_bucket.photos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
