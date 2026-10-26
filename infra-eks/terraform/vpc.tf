# ---------------------------------------------------------------
# Network for the cluster (official module terraform-aws-modules/vpc)
#   2 public subnets  -> load balancers (internet facing)
#   2 private subnets -> worker nodes (no public IPs)
#   1 NAT gateway     -> lets private nodes reach the internet (pull images, AWS APIs)
# ---------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.19"

  name = "${var.name_prefix}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # one NAT for both AZs: cheaper, fine for class
  enable_dns_hostnames = true

  # Tell Kubernetes which subnets to use for load balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}
