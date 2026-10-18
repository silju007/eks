# Copy this folder to projects/<your-project>/ and fill in the values.
#   cp -r projects/_template projects/myproject
#
# Values shared by ALL roots (bootstrap, global, shared).
name_prefix = "REPLACE_ME" # short project slug, e.g. "example-project" — drives all resource names + the state bucket
region      = "us-east-1"

# Target account/identity for this project. Leave both empty to use your
# default credential chain (env vars, default profile, instance role, …).
aws_profile     = "" # named AWS CLI profile
assume_role_arn = "" # role to assume, e.g. "arn:aws:iam::ACCOUNT_ID:role/terraform"

tags = {
  Project   = "REPLACE_ME"
  ManagedBy = "terraform"
  Owner     = "REPLACE_ME"
}
