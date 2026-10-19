# Least-privilege CI role assumed to run terraform plan/apply.
#
# The role's PERMISSIONS are scoped to (a) the remote-state bucket + its KMS key
# and (b) the AWS services this codebase manages. It deliberately does NOT grant
# "*". Tighten resource ARNs further per your account conventions.
#
# The role's TRUST accepts two independent sources (either or both):
#   1. Plain AWS principals listed in ci_trusted_principal_arns (users/roles).
#   2. Bitbucket Pipelines via OIDC — set bitbucket_workspace (+ its UUID). This
#      creates an IAM OIDC provider for the workspace and lets pipelines exchange
#      their step token for this role with `sts:AssumeRoleWithWebIdentity` — no
#      long-lived AWS keys stored in Bitbucket.
#
# The role is created when EITHER trust source is configured.

locals {
  bitbucket_oidc_enabled = var.bitbucket_workspace != ""
  ci_enabled             = length(var.ci_trusted_principal_arns) > 0 || local.bitbucket_oidc_enabled

  # OIDC provider host+path (the issuer URL without the scheme). Used both as the
  # provider URL and as the prefix for the sub/aud condition keys.
  bitbucket_oidc_host = "api.bitbucket.org/2.0/workspaces/${var.bitbucket_workspace}/pipelines-config/identity/oidc"
  bitbucket_audience  = "ari:cloud:bitbucket::workspace/${var.bitbucket_workspace_uuid}"
}

# OIDC identity provider for the Bitbucket workspace. One per workspace/account.
resource "aws_iam_openid_connect_provider" "bitbucket" {
  count = local.bitbucket_oidc_enabled ? 1 : 0

  url             = "https://${local.bitbucket_oidc_host}"
  client_id_list  = [local.bitbucket_audience]
  thumbprint_list = ["a031c46782e6e6c662c2c87c76da9aa62ccabd8e"]
  tags            = var.tags
}

data "aws_iam_policy_document" "ci_assume" {
  count = local.ci_enabled ? 1 : 0

  # Trust source 1: plain AWS principals (IAM users/roles).
  dynamic "statement" {
    for_each = length(var.ci_trusted_principal_arns) > 0 ? [1] : []
    content {
      sid     = "TrustAwsPrincipals"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]

      principals {
        type        = "AWS"
        identifiers = var.ci_trusted_principal_arns
      }
    }
  }

  # Trust source 2: Bitbucket Pipelines via OIDC web identity.
  dynamic "statement" {
    for_each = local.bitbucket_oidc_enabled ? [1] : []
    content {
      sid     = "TrustBitbucketOIDC"
      effect  = "Allow"
      actions = ["sts:AssumeRoleWithWebIdentity"]

      principals {
        type        = "Federated"
        identifiers = [aws_iam_openid_connect_provider.bitbucket[0].arn]
      }

      # Lock the audience to this workspace.
      condition {
        test     = "StringEquals"
        variable = "${local.bitbucket_oidc_host}:aud"
        values   = [local.bitbucket_audience]
      }

      # Scope the subject to a specific repo (<repo-uuid>:*) when provided,
      # otherwise allow any repo/step in the workspace.
      condition {
        test     = "StringLike"
        variable = "${local.bitbucket_oidc_host}:sub"
        values   = [var.bitbucket_repo_uuid != "" ? "${var.bitbucket_repo_uuid}:*" : "*"]
      }
    }
  }
}

resource "aws_iam_role" "ci" {
  count = local.ci_enabled ? 1 : 0

  name               = "${var.name_prefix}-terraform-ci"
  assume_role_policy = data.aws_iam_policy_document.ci_assume[0].json
  tags               = var.tags
}

# State access: read/write the state bucket and use its KMS key.
data "aws_iam_policy_document" "ci_state" {
  count = local.ci_enabled ? 1 : 0

  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [module.state_bucket.s3_bucket_arn]
  }

  statement {
    sid    = "StateObjectRW"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${module.state_bucket.s3_bucket_arn}/*"]
  }

  statement {
    sid    = "StateKmsUse"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.state.arn]
  }
}

# Resource management: the services this platform provisions.
data "aws_iam_policy_document" "ci_manage" {
  count = local.ci_enabled ? 1 : 0

  statement {
    sid    = "PlatformManage"
    effect = "Allow"
    actions = [
      "ec2:*",
      "eks:*",
      "iam:*",
      "kms:*",
      "logs:*",
      "route53:*",
      "ecr:*",
      "wafv2:*",
      "sqs:*",
      "events:*",
      "autoscaling:*",
      "elasticloadbalancing:*",
      "s3:*",
      "secretsmanager:*",
      "ssm:*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ci_state" {
  count = local.ci_enabled ? 1 : 0

  name   = "state-access"
  role   = aws_iam_role.ci[0].id
  policy = data.aws_iam_policy_document.ci_state[0].json
}

resource "aws_iam_role_policy" "ci_manage" {
  count = local.ci_enabled ? 1 : 0

  name   = "platform-manage"
  role   = aws_iam_role.ci[0].id
  policy = data.aws_iam_policy_document.ci_manage[0].json
}
