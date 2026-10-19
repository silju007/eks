# shared-cluster values.
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

# Restrict to CI egress + admin IPs. 0.0.0.0/0 is only a placeholder.
endpoint_public_access_cidrs = ["0.0.0.0/0"]

# --- Team access (namespace-scoped) ---
# Real IAM role ARNs that ALREADY EXIST in this project's account, or "" to skip.
dev_team_role_arn     = ""
staging_team_role_arn = ""

# Cluster-admin principals. For SSO use the PATH-LESS role ARN
# (role/AWSReservedSSO_<name>_<hash>) or EKS will show a perpetual diff.
cluster_admin_principal_arns = []

# CI applies need cluster-admin (auth mode = API). When true and Terraform runs
# as an assumed role (e.g. the Bitbucket CI role), that role's ARN is added to
# the cluster-admin access entries automatically. No-ops for non-assumed-role
# callers, so it's safe to leave enabled.
grant_ci_cluster_admin = true

# --- Observability ---
log_retention_days = 14

# --- GitOps handoff ---
gitops_repo_url        = "https://github.com/your-org/REPLACE_ME-gitops.git"
gitops_target_revision = "main"
argocd_chart_version   = "10.1.2"
