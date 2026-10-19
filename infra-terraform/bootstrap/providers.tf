provider "aws" {
  region  = var.region
  profile = var.aws_profile != "" ? var.aws_profile : null

  # Optionally assume a role in the project's target account.
  dynamic "assume_role" {
    for_each = var.assume_role_arn != "" ? [1] : []
    content {
      role_arn     = var.assume_role_arn
      session_name = "terraform-${var.name_prefix}"
    }
  }

  default_tags {
    tags = var.tags
  }
}
