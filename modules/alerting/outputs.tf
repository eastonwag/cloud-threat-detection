output "alert_topic_arn" {
  description = "ARN of the SNS topic for security alerts"
  value       = aws_sns_topic.alerts.arn
}
