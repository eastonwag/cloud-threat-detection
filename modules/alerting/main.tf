# SNS topic for security alerts
# HIGH/CRITICAL findings notify via Step Functions; MEDIUM findings route directly here.

resource "aws_sns_topic" "alerts" {
  name = "${var.prefix}-security-alerts-${var.environment}"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
