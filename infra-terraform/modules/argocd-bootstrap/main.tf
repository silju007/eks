# One-time GitOps handoff: install ArgoCD, then apply the root app-of-apps.
# After this, ArgoCD owns everything else in the cluster. Keep this minimal —
# do not manage platform addons or app manifests here.

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.namespace
  create_namespace = true

  # Let CRDs install with the release so the root Application can be applied next.
  wait = true
}

# Optional SSH credential for a private GitOps repo. When gitops_ssh_private_key
# is set, create the Secret ArgoCD recognizes as a repository credential
# (label argocd.argoproj.io/secret-type: repository). The `url` must match the
# Application repoURL exactly. Host-key verification uses ArgoCD's default
# argocd-ssh-known-hosts-cm, which already includes bitbucket.org.
resource "kubernetes_secret_v1" "gitops_repo" {
  count = var.gitops_ssh_private_key != "" ? 1 : 0

  metadata {
    name      = "gitops-repo"
    namespace = var.namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  # kubernetes_secret_v1 base64-encodes these; values stay sensitive in state.
  data = {
    type          = "git"
    url           = var.gitops_repo_url
    sshPrivateKey = var.gitops_ssh_private_key
  }

  depends_on = [helm_release.argocd]
}

# Root app-of-apps: ArgoCD reconciles everything under gitops_bootstrap_path.
resource "kubectl_manifest" "root_app" {
  # Credential (if any) must exist before ArgoCD tries to clone the repo.
  depends_on = [helm_release.argocd, kubernetes_secret_v1.gitops_repo]

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.root_app_name
      namespace = var.namespace
      finalizers = [
        "resources-finalizer.argocd.argoproj.io",
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_target_revision
        path           = var.gitops_bootstrap_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
        ]
      }
    }
  })
}
