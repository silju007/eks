provider "aws" {
  region  = var.region
  profile = var.aws_profile != "" ? var.aws_profile : null

  # Optionally assume a role in the project's target account.
  dynamic "assume_role" {
    for_each = var.assume_role_arn != "" ? [1] : []
    content {
      role_arn     = var.assume_role_arn
      session_name = "terraform-${var.name_prefix}"
    }
  }

  default_tags {
    tags = var.tags
  }
}

locals {
  # `aws eks get-token` must authenticate as the same identity the aws provider
  # uses, so thread the project's profile / assume-role through the exec args.
  eks_token_args = concat(
    ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region],
    var.aws_profile != "" ? ["--profile", var.aws_profile] : [],
    var.assume_role_arn != "" ? ["--role-arn", var.assume_role_arn] : [],
  )
}

# kubernetes / helm / kubectl authenticate to the cluster with a short-lived
# token from the AWS CLI exec plugin (no static kubeconfig). Only the
# argocd-bootstrap module + the gp3 StorageClass resources use these providers,
# so the rest of the plan stays AWS-only.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = local.eks_token_args
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = local.eks_token_args
    }
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = local.eks_token_args
  }
}
