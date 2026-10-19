terraform {
  required_version = ">= 1.9"

  # Bootstrap intentionally uses LOCAL state: it creates the S3 bucket + KMS key
  # that every other root then uses as its remote backend. Commit the resulting
  # terraform.tfstate (or keep it safe) — it is small and only holds backend infra.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
