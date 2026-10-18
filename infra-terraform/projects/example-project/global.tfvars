# Example global-only values (ECR + Route 53). Replace the domain before applying.
domain_name = "example.com"

ecr_repositories          = ["service-a", "service-b", "service-c"]
ecr_image_retention_count = 20

# --- Team access roles ---
# Principals allowed to assume each team role (e.g. IAM user/role/SSO ARNs in
# target account). Leave empty to skip creating that role. The role ARNs
# are exported and consumed automatically by the shared cluster's access entries.
dev_team_trusted_principals     = [] # e.g. ["arn:aws:iam::ACCOUNT_ID:root"] or specific user/role ARNs
staging_team_trusted_principals = []
