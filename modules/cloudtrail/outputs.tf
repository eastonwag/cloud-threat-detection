output "log_bucket_name" {
  description = "Name of the S3 bucket receiving CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_logs.id
}

output "log_bucket_arn" {
  description = "ARN of the CloudTrail log S3 bucket"
  value       = aws_s3_bucket.cloudtrail_logs.arn
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for real-time CloudTrail stream"
  value       = aws_cloudwatch_log_group.cloudtrail.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for CloudTrail log encryption"
  value       = aws_kms_key.cloudtrail.arn
}
