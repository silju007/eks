# Canonical provider pins for the whole repo (reference).
#
# Terraform does NOT merge this file across roots — each root (bootstrap/,
# global/, environments/shared/) and each module declares its own terraform{}
# block. This file documents the single source of truth for the pinned versions
# so they stay consistent everywhere:
#
#   terraform            >= 1.9
#   hashicorp/aws        ~> 6.0
#   hashicorp/kubernetes ~> 2.0
#   hashicorp/helm       ~> 2.0
#   gavinbunney/kubectl  ~> 1.0
#
# Upstream module pins:
#   terraform-aws-modules/vpc/aws                                  ~> 6.0
#   terraform-aws-modules/eks/aws                                  ~> 21.0
#   terraform-aws-modules/eks/aws//modules/karpenter               ~> 21.0
#   terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts ~> 6.0
#   terraform-aws-modules/s3-bucket/aws                            ~> 4.0
terraform {
  required_version = ">= 1.9"
}
