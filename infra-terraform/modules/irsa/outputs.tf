output "aws_lb_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller."
  value       = module.aws_lb_controller.arn
}

output "external_dns_role_arn" {
  description = "IRSA role ARN for external-dns."
  value       = module.external_dns.arn
}

output "cert_manager_role_arn" {
  description = "IRSA role ARN for cert-manager."
  value       = module.cert_manager.arn
}

output "external_secrets_role_arn" {
  description = "IRSA role ARN for External Secrets Operator."
  value       = module.external_secrets.arn
}

output "fluent_bit_role_arn" {
  description = "IRSA role ARN for Fluent Bit."
  value       = module.fluent_bit.arn
}

output "velero_role_arn" {
  description = "IRSA role ARN for Velero."
  value       = module.velero.arn
}

output "ebs_csi_role_arn" {
  description = "IRSA role ARN for the EBS CSI driver (wired into the eks addon)."
  value       = module.ebs_csi.arn
}
