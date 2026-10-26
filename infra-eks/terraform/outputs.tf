output "cluster_name" {
  value = module.eks.cluster_name
}

output "region" {
  value = var.region
}

output "photos_bucket" {
  value = aws_s3_bucket.photos.bucket
}

output "ecr_backend_url" {
  value = aws_ecr_repository.app["backend"].repository_url
}

output "ecr_frontend_url" {
  value = aws_ecr_repository.app["frontend"].repository_url
}

output "configure_kubectl" {
  description = "Run this to use kubectl against the cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
