# Example shared-cluster values. Replace placeholders before applying.
environment = "shared"

# --- Networking ---
vpc_cidr = "10.0.0.0/16"
azs      = ["us-east-1a", "us-east-1b", "us-east-1c"]

# --- EKS ---
kubernetes_version  = "1.36"
node_instance_types = ["m6i.large"]
node_min_size       = 2
node_desired_size   = 3
node_max_size       = 4

# Restrict this to CI egress + admin IPs. 0.0.0.0/0 is only a placeholder.
endpoint_public_access_cidrs = ["0.0.0.0/0"]

# --- Team access (namespace-scoped) ---
# Set to real IAM role ARNs that already exist in the target account to
# grant namespace-scoped cluster access; leave empty to skip. EKS rejects
# principals that don't exist or live in another account. For SSO users, use the
# IAM Identity Center permission-set role ARN.
dev_team_role_arn     = ""
staging_team_role_arn = ""

# Cluster-admin access entries (platform engineers). For IAM Identity Center
# (SSO) principals use the PATH-LESS permission-set role ARN — EKS strips the
# sso path, so the full-path form causes a perpetual diff. Find it with:
#   aws iam list-roles --query "Roles[?contains(RoleName,'AWSReservedSSO')].Arn"
# then drop the /aws-reserved/sso.amazonaws.com/<region>/ path segment, e.g.:
#   "arn:aws:iam::ACCOUNT_ID:role/AWSReservedSSO_AdministratorAccess_<hash>"
#
# The shared root disables creator-admin (enable_cluster_creator_admin_permissions
# =false in main.tf) because applies run from both the SSO admin and the CI role
# and a caller-dependent creator entry thrashes between them. So EVERY human admin
# must be listed here explicitly. The SSO AdministratorAccess role is the operator
# who bootstrapped the cluster and needs kubectl/terraform k8s access.
cluster_admin_principal_arns = []

# Explicit CI-role cluster-admin. Pinned to the role the Bitbucket pipeline
# assumes (CI_ROLE_ARN) so the CI access entry is STABLE regardless of who runs
# `apply`. Leaving it empty auto-derives the entry from the *current* caller,
# which means a local apply (as the SSO admin) never creates an entry for the CI
# role — so CI fails k8s auth ("Unauthorized") when it reads existing resources.
# Set this to the dedicated CI role ARN after configuring the selected CI
# provider's OIDC trust policy. Do not use a personal administrator role.
terraform_ci_role_arn = ""

# --- Observability ---
log_retention_days = 14

# --- GitOps handoff ---
gitops_repo_url        = "git@bitbucket.org:example-org/example-platform-gitops.git"
gitops_target_revision = "main"
argocd_chart_version   = "10.1.2"
# gitops_ssh_private_key is a SECRET — do NOT set it here. Supply it at apply via
# TF_VAR_gitops_ssh_private_key (locally, raw: "$(cat argocd_gitops)") or the
# GITOPS_SSH_PRIVATE_KEY secured variable in the pipeline (BASE64-encoded —
# Bitbucket flattens newlines, which corrupts a raw PEM key; the pipeline decodes
# it). Empty = ArgoCD gets no repo credential. See docs/argocd-gitops.md.
