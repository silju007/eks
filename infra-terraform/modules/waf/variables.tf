variable "name" {
  description = "Name for the WAFv2 web ACL."
  type        = string
}

variable "rate_limit" {
  description = "Requests allowed per 5-minute window per source IP before the rate-based rule blocks."
  type        = number
  default     = 2000
}

variable "tags" {
  description = "Tags applied to the web ACL."
  type        = map(string)
  default     = {}
}
