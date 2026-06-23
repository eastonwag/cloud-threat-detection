terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "rw-threat-detect-tfstate"
    key            = "threat-detection/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "cloud-threat-detection"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  prefix      = var.prefix
  environment = var.environment
  aws_region  = var.aws_region
}

module "cloudtrail" {
  source = "../../modules/cloudtrail"

  prefix      = var.prefix
  environment = var.environment
  aws_region  = var.aws_region
}

module "guardduty" {
  source = "../../modules/guardduty"

  prefix      = var.prefix
  environment = var.environment
}

module "security_hub" {
  source = "../../modules/security-hub"

  prefix      = var.prefix
  environment = var.environment
  aws_region  = var.aws_region

  depends_on = [module.guardduty]
}

module "alerting" {
  source = "../../modules/alerting"

  prefix             = var.prefix
  environment        = var.environment
  alert_email        = var.alert_email
}

module "incident_response" {
  source = "../../modules/incident-response"

  prefix            = var.prefix
  environment       = var.environment
  aws_region        = var.aws_region
  alert_topic_arn   = module.alerting.alert_topic_arn
  log_bucket_name   = module.cloudtrail.log_bucket_name
  vpc_id            = module.vpc.vpc_id
}
