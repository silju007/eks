# AWS-side Karpenter resources only, via the eks//modules/karpenter submodule:
# controller IAM role, node IAM role, SQS interruption queue, and EventBridge
# rules. The Karpenter Helm chart AND the NodePool / EC2NodeClass CRs are owned
# by GitOps — this module intentionally creates none of them.
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name = var.cluster_name

  # Use EKS Pod Identity rather than OIDC IRSA. The v21 submodule scopes IAM to
  # the Karpenter v1 API by default (the old enable_v1_permissions flag is gone).
  create_pod_identity_association = true

  namespace       = var.namespace
  service_account = var.service_account

  # Native spot interruption handling via the SQS queue + EventBridge rules.
  enable_spot_termination = true

  # Let nodes register via SSM for break-glass debugging.
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags
}
