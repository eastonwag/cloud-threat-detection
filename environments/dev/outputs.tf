output "guardduty_detector_id" {
  description = "GuardDuty detector ID — use with aws guardduty create-sample-findings"
  value       = module.guardduty.detector_id
}

output "cloudtrail_log_bucket" {
  description = "S3 bucket receiving CloudTrail logs"
  value       = module.cloudtrail.log_bucket_name
}

output "alert_topic_arn" {
  description = "SNS topic ARN for security alerts"
  value       = module.alerting.alert_topic_arn
}

output "step_functions_arn" {
  description = "Step Functions state machine ARN for the incident response playbook"
  value       = module.incident_response.state_machine_arn
}
