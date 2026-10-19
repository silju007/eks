output "iam_role_arn" {
  description = "Karpenter controller IAM role ARN."
  value       = module.karpenter.iam_role_arn
}

output "node_iam_role_arn" {
  description = "Karpenter node IAM role ARN."
  value       = module.karpenter.node_iam_role_arn
}

output "node_iam_role_name" {
  description = "Karpenter node IAM role name (referenced by the EC2NodeClass in GitOps)."
  value       = module.karpenter.node_iam_role_name
}

output "queue_name" {
  description = "SQS interruption queue name."
  value       = module.karpenter.queue_name
}

output "instance_profile_name" {
  description = "Instance profile name for Karpenter-provisioned nodes."
  value       = module.karpenter.instance_profile_name
}

output "service_account" {
  description = "Karpenter controller ServiceAccount name (annotated/associated for Pod Identity)."
  value       = module.karpenter.service_account
}
