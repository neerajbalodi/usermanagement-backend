# ---------------------------------------------------------------
# Day 2: IAM role for the BACKEND server
# The Spring Boot app gets temporary AWS credentials from this role
# (same idea as the Jenkins server's role). No keys in code or Git.
# Least privilege: only put/get/delete objects in the photos bucket.
# ---------------------------------------------------------------

# Who may use the role: EC2 instances
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backend" {
  name               = "${var.name_prefix}-backend-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# What the role may do: only these three actions, only in this bucket
data "aws_iam_policy_document" "backend_s3" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.photos.arn}/*"]
  }
}

resource "aws_iam_role_policy" "backend_s3" {
  name   = "${var.name_prefix}-backend-s3"
  role   = aws_iam_role.backend.id
  policy = data.aws_iam_policy_document.backend_s3.json
}

# EC2 attaches a role through an "instance profile"
resource "aws_iam_instance_profile" "backend" {
  name = "${var.name_prefix}-backend-profile"
  role = aws_iam_role.backend.name
}
