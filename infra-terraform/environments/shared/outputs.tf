# ---------------------------------------------------------------------------
# Interface to the GitOps repo (§7). These outputs are consumed by ArgoCD
# manifests: ServiceAccount role annotations, Karpenter EC2NodeClass, ingress
# WAF annotation, external-dns zone, ECR image references, etc.
# ---------------------------------------------------------------------------

# Cluster
output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_provider_arn" {
  description = "Cluster OIDC provider ARN."
  value       = module.eks.oidc_provider_arn
}

output "region" {
  description = "AWS region."
  value       = var.region
}

# Controller IRSA role ARNs
output "aws_lb_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller."
  value       = module.irsa.aws_lb_controller_role_arn
}

output "external_dns_role_arn" {
  description = "IRSA role ARN for external-dns."
  value       = module.irsa.external_dns_role_arn
}

output "cert_manager_role_arn" {
  description = "IRSA role ARN for cert-manager."
  value       = module.irsa.cert_manager_role_arn
}

output "external_secrets_role_arn" {
  description = "IRSA role ARN for External Secrets Operator."
  value       = module.irsa.external_secrets_role_arn
}

output "fluent_bit_role_arn" {
  description = "IRSA role ARN for Fluent Bit."
  value       = module.irsa.fluent_bit_role_arn
}

output "velero_role_arn" {
  description = "IRSA role ARN for Velero."
  value       = module.irsa.velero_role_arn
}

# Karpenter
output "karpenter_role_arn" {
  description = "Karpenter controller IAM role ARN."
  value       = module.karpenter.iam_role_arn
}

output "karpenter_node_iam_role_arn" {
  description = "Karpenter node IAM role ARN."
  value       = module.karpenter.node_iam_role_arn
}

output "karpenter_queue_name" {
  description = "Karpenter interruption SQS queue name."
  value       = module.karpenter.queue_name
}

output "karpenter_instance_profile" {
  description = "Karpenter node instance profile name."
  value       = module.karpenter.instance_profile_name
}

# Observability / WAF / DNS / registries
output "cloudwatch_log_group_name" {
  description = "Primary CloudWatch log group name for container logs."
  value       = module.observability.primary_log_group_name
}

output "waf_web_acl_arn" {
  description = "WAFv2 web ACL ARN (annotate the in-cluster ALB with this)."
  value       = module.waf.web_acl_arn
}

output "route53_zone_id" {
  description = "Public hosted zone ID (from global)."
  value       = data.terraform_remote_state.global.outputs.route53_zone_id
}

output "route53_zone_name" {
  description = "Public hosted zone name (from global)."
  value       = data.terraform_remote_state.global.outputs.route53_zone_name
}

output "ecr_repository_urls" {
  description = "Map of service short name => ECR repository URL (from global)."
  value       = data.terraform_remote_state.global.outputs.ecr_repository_urls
}
