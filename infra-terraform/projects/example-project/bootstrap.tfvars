# Example bootstrap-only values. Replace placeholders before applying.

# --- CI trust: plain AWS principals ------------------------------------------
# IAM principals (users/roles) allowed to assume the CI plan/apply role.
# Leave empty if you only use Bitbucket OIDC below.
ci_trusted_principal_arns = []

# --- CI trust: Bitbucket Pipelines via OIDC ----------------------------------
# Set these to let Bitbucket Pipelines assume the CI role with no stored AWS
# keys. Find the workspace UUID + repo UUID in Repository settings ->
# OpenID Connect (the Audience is ari:cloud:bitbucket::workspace/<uuid>).
# Leave bitbucket_workspace empty to skip OIDC entirely.
bitbucket_workspace      = "" # e.g. "example-org"
bitbucket_workspace_uuid = "" # e.g. "{1234abcd-....}" (used as the OIDC audience)
bitbucket_repo_uuid      = "" # e.g. "{5678efgh-....}" (scopes sub to this repo)

# state_bucket_name is left unset on purpose — bootstrap derives it as
# "<name_prefix>-eks-tfstate-<account_id>". Set it here only to override.
