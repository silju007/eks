# Partial backend config: bucket + region come from the per-project backend.hcl
# at init time (`terraform init -backend-config=.../backend.hcl`), so this file
# stays project-agnostic. The Makefile wires this up automatically.
terraform {
  backend "s3" {
    key          = "global/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
