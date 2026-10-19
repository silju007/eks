output "log_group_names" {
  description = "Map of logical name => CloudWatch log group name."
  value       = { for k, lg in aws_cloudwatch_log_group.this : k => lg.name }
}

output "log_group_arns" {
  description = "Map of logical name => CloudWatch log group ARN (used to scope the Fluent Bit IRSA role)."
  value       = { for k, lg in aws_cloudwatch_log_group.this : k => lg.arn }
}

output "primary_log_group_name" {
  description = "Primary (application) log group name, exported as the §7 cloudwatch_log_group_name output."
  value       = aws_cloudwatch_log_group.this["application"].name
}
