# KMS keys (consumed by the shared environment via remote state).
output "kms_eks_secrets_key_arn" {
  description = "ARN of the EKS secrets encryption key."
  value       = aws_kms_key.eks_secrets.arn
}

output "kms_logs_key_arn" {
  description = "ARN of the CloudWatch Logs encryption key."
  value       = aws_kms_key.logs.arn
}

output "kms_ebs_key_arn" {
  description = "ARN of the EBS encryption key."
  value       = aws_kms_key.ebs.arn
}

output "kms_s3_backup_key_arn" {
  description = "ARN of the S3 backup (Velero) encryption key."
  value       = aws_kms_key.s3_backup.arn
}

# Route53.
output "route53_zone_id" {
  description = "Public hosted zone ID."
  value       = aws_route53_zone.public.zone_id
}

output "route53_zone_name" {
  description = "Public hosted zone name."
  value       = aws_route53_zone.public.name
}

output "route53_zone_arn" {
  description = "Public hosted zone ARN (used to scope external-dns/cert-manager roles)."
  value       = aws_route53_zone.public.arn
}

# ECR.
output "ecr_repository_urls" {
  description = "Map of repository short name => repository URL."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "ci_image_repository_url" {
  description = "ECR repository URL for the CI runner image (see ci/Dockerfile)."
  value       = aws_ecr_repository.ci.repository_url
}

# Team access roles (consumed by shared -> EKS access entries via remote state).
# Empty string when the role isn't created (no trusted principals configured).
output "dev_team_role_arn" {
  description = "ARN of the dev-team assumable role (\"\" if not created)."
  value       = try(aws_iam_role.team["dev-team"].arn, "")
}

output "staging_team_role_arn" {
  description = "ARN of the staging-team assumable role (\"\" if not created)."
  value       = try(aws_iam_role.team["staging-team"].arn, "")
}
