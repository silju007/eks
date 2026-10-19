# Human-assumable IAM roles for the app teams (account-level identity).
#
# These roles are what engineers ASSUME; the cluster then maps each role to a
# namespace-scoped EKS access entry (see modules/eks + environments/shared).
# They live here (account-wide state) rather than in the cluster root because
# "who can log in" is account identity, not cluster infrastructure — and global
# applies before shared, so the principals exist before the access entries
# reference them.
#
# Each role is created only when at least one trusted principal is given; its
# ARN is exported (empty string otherwise) and read by shared via remote state.

locals {
  team_roles = {
    dev-team     = var.dev_team_trusted_principals
    staging-team = var.staging_team_trusted_principals
  }

  # Only create roles that have at least one trusted principal.
  enabled_team_roles = { for name, principals in local.team_roles : name => principals if length(principals) > 0 }
}

data "aws_iam_policy_document" "team_assume" {
  for_each = local.enabled_team_roles

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = each.value
    }
  }
}

resource "aws_iam_role" "team" {
  for_each = local.enabled_team_roles

  name               = "${var.name_prefix}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.team_assume[each.key].json
  tags               = var.tags
}

# Minimum needed for `aws eks update-kubeconfig` / kubectl auth. Actual in-cluster
# permissions come from the namespace-scoped EKS access entry, not from IAM.
data "aws_iam_policy_document" "team_eks_describe" {
  count = length(local.enabled_team_roles) > 0 ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "team_eks_describe" {
  for_each = local.enabled_team_roles

  name   = "eks-describe"
  role   = aws_iam_role.team[each.key].id
  policy = data.aws_iam_policy_document.team_eks_describe[0].json
}
