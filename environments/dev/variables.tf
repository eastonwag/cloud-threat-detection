variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, prod)"
  type        = string
  default     = "dev"
}

variable "prefix" {
  description = "Short prefix for naming resources (e.g. your initials or project abbreviation)"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive SNS security alerts"
  type        = string
}
