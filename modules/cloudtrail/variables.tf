variable "prefix" {
  description = "Short prefix for naming resources — must produce globally unique S3 bucket names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
}
