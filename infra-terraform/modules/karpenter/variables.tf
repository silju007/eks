variable "cluster_name" {
  description = "EKS cluster name Karpenter manages nodes for."
  type        = string
}

variable "namespace" {
  description = "Namespace the Karpenter controller runs in (installed via GitOps)."
  type        = string
  default     = "kube-system"
}

variable "service_account" {
  description = "Karpenter controller ServiceAccount name."
  type        = string
  default     = "karpenter"
}

variable "tags" {
  description = "Tags applied to Karpenter AWS resources."
  type        = map(string)
  default     = {}
}
