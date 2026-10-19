data "aws_caller_identity" "current" {}

locals {
  # Derive a globally-unique bucket name from the project prefix + account id,
  # unless an explicit override is supplied. This is the ONE place the state
  # bucket name is defined; global/ and shared/ reference the same formula.
  state_bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : "${var.name_prefix}-eks-tfstate-${data.aws_caller_identity.current.account_id}"
}

# KMS key that encrypts the remote-state bucket contents.
resource "aws_kms_key" "state" {
  description             = "${var.name_prefix} Terraform remote state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "state" {
  name          = "alias/${var.name_prefix}-tfstate"
  target_key_id = aws_kms_key.state.key_id
}

# Remote-state bucket: versioned, SSE-KMS, public access fully blocked.
# State locking uses S3-native lockfiles (use_lockfile = true in backend.tf),
# so no DynamoDB table is required.
module "state_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = local.state_bucket_name

  # Block all public access.
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.state.arn
        sse_algorithm     = "aws:kms"
      }
      bucket_key_enabled = true
    }
  }

  tags = var.tags
}
