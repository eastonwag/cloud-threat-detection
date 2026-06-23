output "detector_id" {
  description = "GuardDuty detector ID — pass to aws guardduty create-sample-findings for testing"
  value       = aws_guardduty_detector.main.id
}
