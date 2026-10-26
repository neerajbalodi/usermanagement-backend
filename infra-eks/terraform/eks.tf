# ---------------------------------------------------------------
# EKS cluster (official module terraform-aws-modules/eks)
#   Control plane : run by AWS
#   Worker nodes  : managed node group of EC2 instances in the private subnets
#   Add-ons       : networking (vpc-cni, kube-proxy, coredns),
#                   Pod Identity agent (gives pods IAM roles),
#                   EBS CSI driver (real disks for PostgreSQL) - see below
# ---------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  # Jenkins runs outside the VPC, so the Kubernetes API must be reachable
  cluster_endpoint_public_access = true

  # Whoever runs Terraform (the Jenkins role) becomes cluster admin,
  # so the pipelines can use kubectl
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Kept lean for class: fewer AWS permissions needed and lower cost
  create_kms_key              = false
  cluster_encryption_config   = {}
  create_cloudwatch_log_group = false
  cluster_enabled_log_types   = []
  enable_irsa                 = false # we use EKS Pod Identity instead

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
    eks-pod-identity-agent = { before_compute = true }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.node_instance_type]

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
    }
  }

  # Optional: give your own IAM user/role admin access too
  access_entries = var.admin_principal_arn == "" ? {} : {
    admin = {
      principal_arn = var.admin_principal_arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}

# EBS CSI driver: lets Kubernetes create EBS disks (for the PostgreSQL volume).
# It needs its own IAM role, given to its service account through Pod Identity.
resource "aws_iam_role" "ebs_csi" {
  name               = "${var.name_prefix}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  # The role must exist before the driver starts, and nodes must be running
  depends_on = [aws_eks_pod_identity_association.ebs_csi, module.eks]
}
