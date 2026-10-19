data "aws_caller_identity" "current" {}

locals {
  cluster_name = "${var.name_prefix}-${var.environment}"

  # The kubernetes/helm providers authenticate via `aws eks get-token`, which
  # requires an EKS access entry — IAM eks:* alone is not enough with
  # authentication_mode=API. In CI, Terraform already runs AS the CI role, so
  # derive that role's IAM ARN from the assumed-role caller identity
  # (arn:aws:sts::<acct>:assumed-role/<role-name>/<session>) rather than looking
  # it up by a guessed name (the name/account can differ per project).
  caller_arn_parts = split("/", data.aws_caller_identity.current.arn)
  is_assumed_role  = length(local.caller_arn_parts) == 3 && can(regex(":assumed-role/", data.aws_caller_identity.current.arn))
  caller_role_arn = local.is_assumed_role ? format(
    "arn:aws:iam::%s:role/%s",
    data.aws_caller_identity.current.account_id,
    local.caller_arn_parts[1],
  ) : ""

  # Same derivation as bootstrap — no need to pass the bucket name around.
  state_bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : "${var.name_prefix}-eks-tfstate-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Environment = var.environment
  })

  # Team access-entry principals: prefer an explicit override in shared.tfvars,
  # otherwise take the role global created and exported. try() tolerates a global
  # state that predates these outputs (returns "" -> access entry skipped).
  dev_team_role_arn     = var.dev_team_role_arn != "" ? var.dev_team_role_arn : try(data.terraform_remote_state.global.outputs.dev_team_role_arn, "")
  staging_team_role_arn = var.staging_team_role_arn != "" ? var.staging_team_role_arn : try(data.terraform_remote_state.global.outputs.staging_team_role_arn, "")

  terraform_ci_role_arn = !var.grant_ci_cluster_admin ? "" : (
    var.terraform_ci_role_arn != "" ? var.terraform_ci_role_arn : local.caller_role_arn
  )

  cluster_admin_principal_arns = concat(
    var.cluster_admin_principal_arns,
    local.terraform_ci_role_arn != "" ? [local.terraform_ci_role_arn] : [],
  )
}

# Read account-wide resources (KMS keys, Route53 zone, ECR) from the global state.
data "terraform_remote_state" "global" {
  backend = "s3"

  config = {
    bucket = local.state_bucket_name
    key    = "global/terraform.tfstate"
    region = var.region
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name         = local.cluster_name
  cidr         = var.vpc_cidr
  azs          = var.azs
  cluster_name = local.cluster_name
  tags         = local.tags
}

module "eks" {
  source = "../../modules/eks"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  kms_key_arn                  = data.terraform_remote_state.global.outputs.kms_eks_secrets_key_arn

  # EBS CSI addon role from the irsa module. Terraform resolves this against the
  # specific IAM role resource (not the whole eks module), so there is no cycle
  # even though irsa itself depends on module.eks.oidc_provider_arn.
  ebs_csi_role_arn = module.irsa.ebs_csi_role_arn

  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size

  dev_team_role_arn            = local.dev_team_role_arn
  staging_team_role_arn        = local.staging_team_role_arn
  cluster_admin_principal_arns = local.cluster_admin_principal_arns

  # Applies run from both a human SSO admin (local) and the CI role. The
  # caller-dependent creator-admin entry would thrash/409 between them, so it is
  # disabled here — every admin is listed explicitly in cluster_admin_principal_arns
  # / terraform_ci_role_arn instead.
  enable_cluster_creator_admin_permissions = false

  tags = local.tags
}

module "karpenter" {
  source = "../../modules/karpenter"

  cluster_name = module.eks.cluster_name
  tags         = local.tags
}

module "observability" {
  source = "../../modules/observability"

  name_prefix        = local.cluster_name
  kms_key_arn        = data.terraform_remote_state.global.outputs.kms_logs_key_arn
  log_retention_days = var.log_retention_days
  tags               = local.tags
}

# S3 bucket for Velero backups, encrypted with the shared s3-backup KMS key.
module "velero_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = "${local.cluster_name}-velero-backups"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = data.terraform_remote_state.global.outputs.kms_s3_backup_key_arn
        sse_algorithm     = "aws:kms"
      }
      bucket_key_enabled = true
    }
  }

  tags = local.tags
}

module "irsa" {
  source = "../../modules/irsa"

  name_prefix       = local.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  route53_zone_arn  = data.terraform_remote_state.global.outputs.route53_zone_arn
  log_group_arns    = values(module.observability.log_group_arns)
  velero_bucket_arn = module.velero_bucket.s3_bucket_arn

  external_secrets_kms_key_arns = [data.terraform_remote_state.global.outputs.kms_eks_secrets_key_arn]

  tags = local.tags
}

module "waf" {
  source = "../../modules/waf"

  name = "${local.cluster_name}-web-acl"
  tags = local.tags
}

# GitOps handoff — installs ArgoCD and applies the root app-of-apps.
module "argocd_bootstrap" {
  source = "../../modules/argocd-bootstrap"

  argocd_chart_version   = var.argocd_chart_version
  gitops_repo_url        = var.gitops_repo_url
  gitops_target_revision = var.gitops_target_revision
  gitops_ssh_private_key = var.gitops_ssh_private_key

  # ArgoCD needs a running cluster + core addons before it can install.
  depends_on = [module.eks]
}
