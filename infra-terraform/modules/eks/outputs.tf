output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate."
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA roles."
  value       = module.eks.oidc_provider_arn
}

output "cluster_security_group_id" {
  description = "Cluster (control-plane) security group ID."
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Shared node security group ID."
  value       = module.eks.node_security_group_id
}
