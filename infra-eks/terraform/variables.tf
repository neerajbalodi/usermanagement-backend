variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "name_prefix" {
  description = "Prefix for every resource name"
  type        = string
  default     = "um"
}

variable "cluster_version" {
  description = "Kubernetes version (1.35 is in standard support until March 2027)"
  type        = string
  default     = "1.35"
}

variable "node_instance_type" {
  description = "EC2 type of the worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  description = "Fewest worker nodes (Cluster Autoscaler never goes below)"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Most worker nodes (cost safety limit for Cluster Autoscaler)"
  type        = number
  default     = 5
}

variable "node_desired_size" {
  description = "Worker nodes at creation time"
  type        = number
  default     = 2
}

variable "app_namespace" {
  description = "Kubernetes namespace of the application"
  type        = string
  default     = "user-management"
}

variable "admin_principal_arn" {
  description = "Optional: IAM user/role ARN that should also get admin access to the cluster (e.g. your own user, to run kubectl from your laptop)"
  type        = string
  default     = ""
}

locals {
  cluster_name = "${var.name_prefix}-eks"
}
