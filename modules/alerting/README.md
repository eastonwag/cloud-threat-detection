# Module: alerting

Creates an SNS topic and email subscription for security alerts.

MEDIUM findings route directly to this topic. HIGH/CRITICAL findings are routed through Step Functions first, then notify via this topic after initiating automated response.

SNS will send a confirmation email to `alert_email` on first apply — confirm it to activate notifications.
