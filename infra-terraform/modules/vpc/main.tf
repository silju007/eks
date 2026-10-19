# Thin wrapper around terraform-aws-modules/vpc/aws.
# Subnet layout derived from the VPC CIDR so callers only pass a /16 + 3 AZs:
#   - private: /20 per AZ (large, for pod-per-IP via VPC-CNI)
#   - public : /24 per AZ (public-facing load balancers)
#   - intra  : /24 per AZ (control-plane ENIs / no NAT egress)
locals {
  private_subnets = [for k in range(length(var.azs)) : cidrsubnet(var.cidr, 4, k)]
  public_subnets  = [for k in range(length(var.azs)) : cidrsubnet(var.cidr, 8, k + 48)]
  intra_subnets   = [for k in range(length(var.azs)) : cidrsubnet(var.cidr, 8, k + 51)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.name
  cidr = var.cidr
  azs  = var.azs

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  intra_subnets   = local.intra_subnets

  # NAT gateway per AZ for high availability (not a single shared NAT).
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required by EKS, the AWS Load Balancer Controller, and Karpenter discovery.
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.cluster_name
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  tags = var.tags
}
