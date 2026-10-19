variable "namespace" {
  description = "Namespace to install ArgoCD into."
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Pinned version of the argo/argo-cd Helm chart."
  type        = string
  default     = "7.8.2"
}

variable "gitops_repo_url" {
  description = "URL of the GitOps repository the root app-of-apps points at."
  type        = string
}

variable "gitops_ssh_private_key" {
  description = "SSH private key (PEM) for ArgoCD to read a private GitOps repo over SSH. When set, creates the ArgoCD repository credential Secret; the matching public key must be a read-only Access Key on the repo. Empty = no credential (public repo, or configured out-of-band)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "gitops_target_revision" {
  description = "Git revision (branch/tag/SHA) ArgoCD tracks in the GitOps repo."
  type        = string
  default     = "main"
}

variable "gitops_bootstrap_path" {
  description = "Path within the GitOps repo containing the root application manifests."
  type        = string
  default     = "bootstrap/"
}

variable "root_app_name" {
  description = "Name of the root app-of-apps Application."
  type        = string
  default     = "root"
}
