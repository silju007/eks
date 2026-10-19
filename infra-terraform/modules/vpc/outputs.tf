output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs (node group + Karpenter workloads)."
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs (public load balancers)."
  value       = module.vpc.public_subnets
}

output "intra_subnets" {
  description = "List of intra subnet IDs (EKS control-plane ENIs)."
  value       = module.vpc.intra_subnets
}
