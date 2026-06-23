variable "prefix" {
  description = "Short prefix for naming resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)"
  type        = string
}

variable "alert_email" {
  description = "Email address for SNS security alert subscriptions"
  type        = string
}
