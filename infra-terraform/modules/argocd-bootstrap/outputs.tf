output "namespace" {
  description = "Namespace ArgoCD was installed into."
  value       = helm_release.argocd.namespace
}

output "argocd_chart_version" {
  description = "Installed argo-cd chart version."
  value       = helm_release.argocd.version
}

output "root_app_name" {
  description = "Name of the root app-of-apps Application."
  value       = var.root_app_name
}
