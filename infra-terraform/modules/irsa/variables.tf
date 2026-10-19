variable "name_prefix" {
  description = "Prefix for role names and for scoping Secrets Manager / SSM paths."
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN (from modules/eks)."
  type        = string
}

variable "route53_zone_arn" {
  description = "ARN of the Route53 hosted zone that external-dns and cert-manager may modify."
  type        = string
}

variable "log_group_arns" {
  description = "CloudWatch log group ARNs Fluent Bit is allowed to write to."
  type        = list(string)
}

variable "velero_bucket_arn" {
  description = "ARN of the S3 bucket used for Velero backups."
  type        = string
}

variable "external_secrets_kms_key_arns" {
  description = "KMS key ARNs External Secrets may use to decrypt Secrets Manager values."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all IRSA roles."
  type        = map(string)
  default     = {}
}
