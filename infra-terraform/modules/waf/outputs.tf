output "web_acl_arn" {
  description = "ARN of the WAFv2 web ACL. Consumed by GitOps to annotate the in-cluster ALB."
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_id" {
  description = "ID of the WAFv2 web ACL."
  value       = aws_wafv2_web_acl.this.id
}
