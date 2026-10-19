variable "name_prefix" {
  description = "Prefix for log group names (e.g. /platform-shared/...)."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the CloudWatch log groups (the 'logs' key from global)."
  type        = string
}

# ⚠️ CloudWatch Logs retention accepts only a fixed set of values:
# 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827,
# 2192, 2557, 2922, 3288, 3653 (and 0 = never expire). There is NO 15-day value.
# 14 is the closest option UNDER a 15-day target; use 30 if you must round up.
variable "log_retention_days" {
  description = "Retention for the CloudWatch log groups. NOTE: 15 is not valid; 14 is the closest value under a 15-day target."
  type        = number
  default     = 14

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.log_retention_days
    )
    error_message = "log_retention_days must be a value CloudWatch Logs accepts (…7, 14, 30… — 15 is NOT valid)."
  }
}

variable "tags" {
  description = "Tags applied to the log groups."
  type        = map(string)
  default     = {}
}
