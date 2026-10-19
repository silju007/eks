output "state_bucket_name" {
  description = "Name of the remote-state S3 bucket (use in each root's backend.tf)."
  value       = module.state_bucket.s3_bucket_id
}

output "state_kms_key_arn" {
  description = "ARN of the KMS key encrypting remote state."
  value       = aws_kms_key.state.arn
}

output "ci_role_arn" {
  description = "ARN of the least-privilege CI plan/apply role (null if none created). Set this as the CI_ROLE_ARN variable in Bitbucket."
  value       = local.ci_enabled ? aws_iam_role.ci[0].arn : null
}

output "bitbucket_oidc_provider_arn" {
  description = "ARN of the Bitbucket Pipelines OIDC provider (null if bitbucket_workspace unset)."
  value       = local.bitbucket_oidc_enabled ? aws_iam_openid_connect_provider.bitbucket[0].arn : null
}

# Copy this into projects/<name>/backend.hcl for the global/ and shared/ roots.
output "backend_hcl" {
  description = "Ready-to-paste partial backend config for the other roots."
  value       = <<-EOT
    bucket = "${module.state_bucket.s3_bucket_id}"
    region = "${var.region}"
  EOT
}
