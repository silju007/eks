# Scoped IRSA (OIDC) roles for the in-cluster controllers that GitOps installs.
# Each role is created with terraform-aws-modules/iam//iam-role-for-service-accounts
# (v6 — note the module was renamed from *-eks in v6). The GitOps repo annotates
# the matching ServiceAccount with each role ARN.
#
# Karpenter and the EBS CSI driver get their roles elsewhere (Karpenter via its
# submodule using Pod Identity; EBS CSI here — see below — wired into the eks addon).

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Path-scope External Secrets to secrets/parameters under the platform prefix.
  external_secrets_secretsmanager_arns = [
    "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/*",
  ]
  external_secrets_ssm_parameter_arns = [
    "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.name_prefix}/*",
  ]
}

# aws-load-balancer-controller (kube-system/aws-load-balancer-controller)
module "aws_lb_controller" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name                                   = "${var.name_prefix}-aws-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

# external-dns (external-dns/external-dns) — Route53 records scoped to the zone.
module "external_dns" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name                          = "${var.name_prefix}-external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [var.route53_zone_arn]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }

  tags = var.tags
}

# cert-manager (cert-manager/cert-manager) — Route53 DNS-01 scoped to the zone.
module "cert_manager" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name                          = "${var.name_prefix}-cert-manager"
  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = [var.route53_zone_arn]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }

  tags = var.tags
}

# external-secrets (external-secrets/external-secrets) — path-scoped SM + SSM.
module "external_secrets" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name                                  = "${var.name_prefix}-external-secrets"
  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = local.external_secrets_secretsmanager_arns
  external_secrets_ssm_parameter_arns   = local.external_secrets_ssm_parameter_arns
  external_secrets_kms_key_arns         = var.external_secrets_kms_key_arns

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  tags = var.tags
}

# fluent-bit (logging/aws-for-fluent-bit) — no built-in module toggle, so attach
# a custom policy scoped to exactly the CloudWatch log groups from observability.
data "aws_iam_policy_document" "fluent_bit" {
  statement {
    sid = "FluentBitCloudWatchLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
    ]
    resources = concat(
      var.log_group_arns,
      [for arn in var.log_group_arns : "${arn}:log-stream:*"],
    )
  }
}

resource "aws_iam_policy" "fluent_bit" {
  name        = "${var.name_prefix}-fluent-bit"
  description = "Scoped CloudWatch Logs write access for aws-for-fluent-bit."
  policy      = data.aws_iam_policy_document.fluent_bit.json
  tags        = var.tags
}

module "fluent_bit" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name = "${var.name_prefix}-fluent-bit"

  policies = {
    cloudwatch = aws_iam_policy.fluent_bit.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["logging:aws-for-fluent-bit"]
    }
  }

  tags = var.tags
}

# velero (velero/velero) — S3 backup bucket + EBS snapshot permissions.
module "velero" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name                 = "${var.name_prefix}-velero"
  attach_velero_policy = true
  velero_s3_bucket_arns = [
    var.velero_bucket_arn,
    "${var.velero_bucket_arn}/*",
  ]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["velero:velero"]
    }
  }

  tags = var.tags
}

# ebs-csi (kube-system/ebs-csi-controller-sa) — role consumed by the eks addon.
module "ebs_csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name                  = "${var.name_prefix}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}
