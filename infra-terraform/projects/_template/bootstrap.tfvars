# bootstrap-only values.

# CI trust source 1 — plain AWS principals allowed to assume the CI role.
# Empty = skip. Prefer an OIDC trust policy for the CI provider.
ci_trusted_principal_arns = []

# Legacy CI trust source — Bitbucket Pipelines via OIDC (no stored AWS keys).
# The bootstrap implementation currently exposes Bitbucket-specific inputs.
# Leave these empty unless Bitbucket is deliberately being used. For GitHub
# Actions, configure the GitHub OIDC provider and repository-scoped trust policy
# separately; never add static AWS keys here.
bitbucket_workspace      = ""
bitbucket_workspace_uuid = ""
bitbucket_repo_uuid      = ""

# Leave state_bucket_name unset to auto-derive "<name_prefix>-eks-tfstate-<account_id>".
