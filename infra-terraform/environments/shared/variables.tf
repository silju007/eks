variable "name_prefix" {
  description = "Name prefix for all resources (combined with environment)."
  type        = string
  default     = "platform"
}

variable "environment" {
  description = "Logical environment name for this cluster root (e.g. shared)."
  type        = string
  default     = "shared"
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "aws_profile" {
  description = "Optional named AWS CLI profile to use for this project (empty = default credential chain). Also threaded into `aws eks get-token`."
  type        = string
  default     = ""
}

variable "assume_role_arn" {
  description = "Optional IAM role ARN to assume in the project's target account (empty = no assume-role). Also threaded into `aws eks get-token`."
  type        = string
  default     = ""
}

variable "state_bucket_name" {
  description = "Optional override for the remote-state bucket name used to read the global state. Leave empty to derive it as <name_prefix>-eks-tfstate-<account_id> (matches bootstrap)."
  type        = string
  default     = ""
}

# --- VPC ---
variable "vpc_cidr" {
  description = "CIDR for the VPC (a /16 is recommended)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Exactly 3 Availability Zones."
  type        = list(string)

  validation {
    condition     = length(var.azs) == 3
    error_message = "Exactly 3 availability zones are required."
  }
}

# --- EKS ---
variable "kubernetes_version" {
  description = "Kubernetes control-plane version."
  type        = string
  default     = "1.36"
}

variable "node_instance_types" {
  description = "Instance types for the bootstrap managed node group."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "node_min_size" {
  description = "Minimum node group size."
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired node group size."
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum node group size."
  type        = number
  default     = 4
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint (CI egress + admin IPs)."
  type        = list(string)
}

# --- Access entries ---
variable "dev_team_role_arn" {
  description = "IAM role ARN for the development team (namespace-scoped access). Must exist in this account. Empty = skip the access entry."
  type        = string
  default     = ""
}

variable "staging_team_role_arn" {
  description = "IAM role ARN for the staging team (namespace-scoped access). Must exist in this account. Empty = skip the access entry."
  type        = string
  default     = ""
}

variable "cluster_admin_principal_arns" {
  description = "IAM principal ARNs granted cluster-admin. For SSO use the PATH-LESS permission-set role ARN (role/AWSReservedSSO_<name>_<hash>)."
  type        = list(string)
  default     = []
}

variable "grant_ci_cluster_admin" {
  description = "Grant cluster-admin to the applying principal (the CI role) so CI can apply kubernetes/helm resources. When true and the caller is an assumed role, its IAM role ARN is auto-derived from the caller identity. Harmless if the identity already has admin (e.g. cluster creator)."
  type        = bool
  default     = true
}

variable "terraform_ci_role_arn" {
  description = "Explicit IAM role ARN to grant cluster-admin. Empty = auto-derive from the caller identity when grant_ci_cluster_admin is true and the caller is an assumed role."
  type        = string
  default     = ""
}

# --- Observability ---
variable "log_retention_days" {
  description = "CloudWatch log retention. NOTE: 15 is not valid; 14 is closest under a 15-day target."
  type        = number
  default     = 14
}

# --- GitOps handoff ---
variable "gitops_repo_url" {
  description = "GitOps repository URL for the ArgoCD root app-of-apps."
  type        = string
}

variable "gitops_target_revision" {
  description = "GitOps repo revision ArgoCD tracks."
  type        = string
  default     = "main"
}

variable "gitops_ssh_private_key" {
  description = "SSH private key for ArgoCD to read a private GitOps repo. Supply via TF_VAR_gitops_ssh_private_key (or a CI secured variable) — do NOT commit it. Empty = no credential."
  type        = string
  default     = ""
  sensitive   = true
}

variable "argocd_chart_version" {
  description = "Pinned argo/argo-cd Helm chart version."
  type        = string
  default     = "7.8.2"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
