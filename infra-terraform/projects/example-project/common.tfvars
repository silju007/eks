# Values shared by ALL roots (bootstrap, global, shared) for the example project.
# The Makefile passes this file first, then the per-root file below.
name_prefix = "example-project"
region      = "us-east-1"

# Target account/identity for this project. Leave both empty to use your
# default credential chain (env vars, default profile, instance role, …).
aws_profile     = "" # named AWS CLI profile, supplied locally when needed
assume_role_arn = "" # e.g. "arn:aws:iam::ACCOUNT_ID:role/terraform"

tags = {
  Project   = "example-project"
  ManagedBy = "terraform"
  Owner     = "platform-team"
}
