variable "name" {
  description = "Base name for the VPC and its subnets (usually name_prefix-environment)."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block. A /16 is recommended to give VPC-CNI enough IPs for pod-per-IP."
  type        = string
}

variable "azs" {
  description = "List of exactly 3 Availability Zone names to spread subnets across."
  type        = list(string)

  validation {
    condition     = length(var.azs) == 3
    error_message = "Exactly 3 availability zones are required."
  }
}

variable "cluster_name" {
  description = "EKS cluster name, used for the karpenter.sh/discovery subnet tag."
  type        = string
}

variable "tags" {
  description = "Tags applied to all VPC resources."
  type        = map(string)
  default     = {}
}
