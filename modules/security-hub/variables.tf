variable "prefix" {
  description = "Short prefix for naming resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region — required to construct standards ARNs"
  type        = string
}
