# ---------------------------------------------------------------
# IAM roles for PODS (EKS Pod Identity)
# On Day 2 the backend EC2 server had a role. Now the role is given to
# one Kubernetes service account, so ONLY the backend pods get it -
# not every pod that happens to run on the same node.
# ---------------------------------------------------------------

# Trust policy shared by all pod roles: "EKS Pod Identity may use this role"
data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# --- Backend: photos bucket only ---------------------------------
resource "aws_iam_role" "backend" {
  name               = "${var.name_prefix}-backend-pod"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

data "aws_iam_policy_document" "backend_s3" {
  statement {
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.photos.arn}/*"]
  }
}

resource "aws_iam_role_policy" "backend_s3" {
  name   = "photos-bucket"
  role   = aws_iam_role.backend.id
  policy = data.aws_iam_policy_document.backend_s3.json
}

# Link: pods using service account "um-backend" in the app namespace get this role
resource "aws_eks_pod_identity_association" "backend" {
  cluster_name    = module.eks.cluster_name
  namespace       = var.app_namespace
  service_account = "um-backend"
  role_arn        = aws_iam_role.backend.arn
}

# --- Cluster Autoscaler: may resize the node group ---------------
resource "aws_iam_role" "cluster_autoscaler" {
  name               = "${var.name_prefix}-cluster-autoscaler"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = ["*"]

    # only node groups that belong to THIS cluster
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/${local.cluster_name}"
      values   = ["owned"]
    }
  }
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name   = "cluster-autoscaler"
  role   = aws_iam_role.cluster_autoscaler.id
  policy = data.aws_iam_policy_document.cluster_autoscaler.json
}

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = aws_iam_role.cluster_autoscaler.arn
}
