variable "name_prefix" {
  description = "Prefix for the state bucket, KMS alias, and CI role names."
  type        = string
  default     = "platform"
}

variable "region" {
  description = "AWS region for the remote-state bucket and KMS key."
  type        = string
}

variable "aws_profile" {
  description = "Optional named AWS CLI profile to use for this project (empty = default credential chain)."
  type        = string
  default     = ""
}

variable "assume_role_arn" {
  description = "Optional IAM role ARN to assume in the project's target account (empty = no assume-role)."
  type        = string
  default     = ""
}

variable "state_bucket_name" {
  description = "Optional override for the remote-state bucket name. Leave empty to derive it as <name_prefix>-eks-tfstate-<account_id> (recommended — keeps it unique and template-friendly)."
  type        = string
  default     = ""
}

variable "ci_trusted_principal_arns" {
  description = "IAM principal ARNs allowed to assume the CI plan/apply role (e.g. a GitHub OIDC role or CI user)."
  type        = list(string)
  default     = []
}

variable "bitbucket_workspace" {
  description = "Bitbucket workspace slug for Pipelines OIDC federation. Set this (with bitbucket_workspace_uuid) to create an IAM OIDC provider and let pipelines assume the CI role without stored AWS keys. Empty = no Bitbucket OIDC."
  type        = string
  default     = ""
}

variable "bitbucket_workspace_uuid" {
  description = "Bitbucket workspace UUID (with braces, e.g. {1234abcd-...}) used as the OIDC audience: ari:cloud:bitbucket::workspace/<uuid>. Required when bitbucket_workspace is set."
  type        = string
  default     = ""
}

variable "bitbucket_repo_uuid" {
  description = "Bitbucket repository UUID (with braces) to scope the OIDC sub claim to <repo-uuid>:*. Empty = trust any repo in the workspace (*). Strongly recommended to set."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to all bootstrap resources."
  type        = map(string)
  default     = {}
}
