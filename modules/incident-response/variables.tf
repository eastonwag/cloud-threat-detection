variable "prefix" {
  description = "Short prefix for naming resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "alert_topic_arn" {
  description = "ARN of the SNS topic for security alert notifications"
  type        = string
}

variable "log_bucket_name" {
  description = "Name of the CloudTrail S3 log bucket — used for response action logging"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — used to create the quarantine security group"
  type        = string
  default     = ""
}
