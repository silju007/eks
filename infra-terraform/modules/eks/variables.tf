variable "name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes control-plane version (e.g. \"1.36\")."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the cluster is deployed into."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the managed node group and cluster ENIs."
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "Intra subnet IDs for the EKS control-plane ENIs."
  type        = list(string)
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint (CI egress + admin IPs)."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for envelope encryption of Kubernetes secrets (the 'eks-secrets' key from global)."
  type        = string
}

variable "ebs_csi_role_arn" {
  description = "IRSA role ARN for the aws-ebs-csi-driver addon (from modules/irsa)."
  type        = string
}

variable "node_instance_types" {
  description = "Instance types for the bootstrap managed node group."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "node_min_size" {
  description = "Minimum size of the bootstrap managed node group."
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired size of the bootstrap managed node group."
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum size of the bootstrap managed node group."
  type        = number
  default     = 4
}

variable "dev_team_role_arn" {
  description = "IAM role ARN for the development team, mapped to a namespace-scoped access entry. Must be an existing role in this cluster's account. Empty = no entry created."
  type        = string
  default     = ""
}

variable "staging_team_role_arn" {
  description = "IAM role ARN for the staging team, mapped to a namespace-scoped access entry. Must be an existing role in this cluster's account. Empty = no entry created."
  type        = string
  default     = ""
}

variable "cluster_admin_principal_arns" {
  description = "IAM principal ARNs granted cluster-admin via access entries. For SSO, use the PATH-LESS permission-set role ARN (role/AWSReservedSSO_<name>_<hash>)."
  type        = list(string)
  default     = []
}

variable "enable_cluster_creator_admin_permissions" {
  description = <<-EOT
    Whether the module adds a cluster-admin access entry for the identity that
    runs `apply` (the "cluster creator"). Leave true for single-operator clusters.
    Set FALSE when applies run from MULTIPLE identities (e.g. a human operator AND
    a CI role): the creator entry re-computes to the current caller on every apply,
    so it thrashes/replaces between callers and can 409 against an explicit entry
    for the same principal. When false, EVERY admin (including whoever bootstraps a
    new cluster) must be listed in cluster_admin_principal_arns instead.
  EOT
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all cluster resources."
  type        = map(string)
  default     = {}
}
