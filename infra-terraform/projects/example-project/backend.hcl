# Partial S3 backend config for the global/ and shared/ roots.
# Fill `bucket` with the value bootstrap prints (terraform output backend_hcl) —
# it will be "<name_prefix>-eks-tfstate-<account_id>". Bootstrap itself uses local state
# and does NOT read this file.
bucket = "REPLACE_WITH_BOOTSTRAP_STATE_BUCKET"
region = "us-east-1"
