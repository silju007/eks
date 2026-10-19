# global-only values (ECR + Route53).
domain_name = "REPLACE_ME.example.com"

ecr_repositories          = ["service-a", "service-b", "service-c"]
ecr_image_retention_count = 20

# Principals allowed to assume each team role (empty = skip creating the role).
# The resulting role ARNs feed the shared cluster's EKS access entries.
dev_team_trusted_principals     = []
staging_team_trusted_principals = []
