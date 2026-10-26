# ---------------------------------------------------------------
# ECR: private image registry, one repository per app
#   um-backend, um-frontend
# The app pipelines push images here; the nodes pull them from here.
# ---------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  for_each = toset(["backend", "frontend"])

  name                 = "${var.name_prefix}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # lets "destroy" remove repos that still hold images (class setting)

  image_scanning_configuration {
    scan_on_push = true # AWS checks every image for known vulnerabilities
  }
}

# Keep only the last 10 images per repository (storage costs money)
resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
