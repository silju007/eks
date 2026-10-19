variable "name_prefix" {
  description = "Prefix for globally-scoped resource names (KMS aliases, ECR repos)."
  type        = string
}

variable "region" {
  description = "AWS region for the global resources."
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

variable "domain_name" {
  description = "Public DNS domain for the Route53 hosted zone (e.g. platform.example.com)."
  type        = string
}

variable "ecr_repositories" {
  description = "ECR repository short names to create."
  type        = list(string)
  default     = ["service-a", "service-b", "service-c"]
}

variable "ecr_image_retention_count" {
  description = "Number of tagged images to retain per ECR repo (lifecycle policy)."
  type        = number
  default     = 20
}

variable "dev_team_trusted_principals" {
  description = "IAM principal ARNs allowed to assume the dev-team role (e.g. SSO/user/role ARNs). Empty = do not create the role."
  type        = list(string)
  default     = []
}

variable "staging_team_trusted_principals" {
  description = "IAM principal ARNs allowed to assume the staging-team role. Empty = do not create the role."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all global resources."
  type        = map(string)
  default     = {}
}
