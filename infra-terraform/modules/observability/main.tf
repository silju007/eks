# KMS-encrypted CloudWatch log groups for application / container logs.
# Fluent Bit (installed via GitOps) ships container logs here; its IRSA role
# (modules/irsa) is scoped to write to exactly these log group ARNs.
#
# retention_in_days = 14 — see the note on var.log_retention_days: CloudWatch
# Logs has no 15-day option, so 14 is the closest value under a 15-day target.

locals {
  log_groups = {
    application = "/${var.name_prefix}/application"
    platform    = "/${var.name_prefix}/platform"
  }
}

resource "aws_cloudwatch_log_group" "this" {
  for_each = local.log_groups

  name              = each.value
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}
