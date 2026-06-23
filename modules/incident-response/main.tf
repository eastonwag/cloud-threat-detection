# Phase 3/4 — EventBridge routing + Step Functions playbook + Lambda response actions
# See docs/project-plan.md Steps 9-12 for the full implementation guide.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ── Quarantine security group (no inbound/outbound = full network isolation) ──

resource "aws_security_group" "quarantine" {
  name        = "${var.prefix}-quarantine-${var.environment}"
  description = "Applied to EC2 instances under incident response - blocks all traffic"
  vpc_id      = var.vpc_id

  # No ingress or egress rules = deny all
}

# ── Lambda: isolate-ec2 ───────────────────────────────────────────────────────

resource "aws_iam_role" "isolate_ec2" {
  name = "${var.prefix}-isolate-ec2-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "isolate_ec2" {
  name = "isolate-ec2-policy"
  role = aws_iam_role.isolate_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Needed to replace security groups on the quarantined instance
        Effect   = "Allow"
        Action   = ["ec2:ModifyInstanceAttribute", "ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        # Needed to tag the instance with quarantine metadata for audit trail
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = "arn:aws:ec2:*:${local.account_id}:instance/*"
      },
      {
        # Basic Lambda execution: write logs to CloudWatch
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      }
    ]
  })
}

data "archive_file" "isolate_ec2" {
  type        = "zip"
  source_file = "${path.root}/../../lambda/isolate-ec2/handler.py"
  output_path = "${path.module}/.build/isolate-ec2.zip"
}

resource "aws_lambda_function" "isolate_ec2" {
  function_name    = "${var.prefix}-isolate-ec2-${var.environment}"
  filename         = data.archive_file.isolate_ec2.output_path
  source_code_hash = data.archive_file.isolate_ec2.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.isolate_ec2.arn
  timeout          = 30

  environment {
    variables = {
      QUARANTINE_SG_ID = aws_security_group.quarantine.id
    }
  }
}

# ── Lambda: revoke-credentials ───────────────────────────────────────────────

resource "aws_iam_role" "revoke_credentials" {
  name = "${var.prefix}-revoke-credentials-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "revoke_credentials" {
  name = "revoke-credentials-policy"
  role = aws_iam_role.revoke_credentials.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Attach deny-all inline policy to freeze the compromised IAM user.
        # Does NOT delete the user — preserves forensic state (keys, attached policies, group memberships).
        Effect   = "Allow"
        Action   = ["iam:PutUserPolicy", "iam:GetUser"]
        Resource = "arn:aws:iam::${local.account_id}:user/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      }
    ]
  })
}

data "archive_file" "revoke_credentials" {
  type        = "zip"
  source_file = "${path.root}/../../lambda/revoke-credentials/handler.py"
  output_path = "${path.module}/.build/revoke-credentials.zip"
}

resource "aws_lambda_function" "revoke_credentials" {
  function_name    = "${var.prefix}-revoke-credentials-${var.environment}"
  filename         = data.archive_file.revoke_credentials.output_path
  source_code_hash = data.archive_file.revoke_credentials.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.revoke_credentials.arn
  timeout          = 30
}

# ── Step Functions state machine ──────────────────────────────────────────────

resource "aws_iam_role" "state_machine" {
  name = "${var.prefix}-incident-response-sfn-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "state_machine" {
  name = "sfn-invoke-lambdas"
  role = aws_iam_role.state_machine.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.isolate_ec2.arn,
          aws_lambda_function.revoke_credentials.arn,
        ]
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = var.alert_topic_arn
      }
    ]
  })
}

resource "aws_sfn_state_machine" "incident_response" {
  name     = "${var.prefix}-incident-response-${var.environment}"
  role_arn = aws_iam_role.state_machine.arn

  definition = jsonencode({
    Comment = "Automated incident response playbook for HIGH/CRITICAL GuardDuty findings"
    StartAt = "NotifySecurityTeam"
    States = {
      NotifySecurityTeam = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = var.alert_topic_arn
          "Message.$" = "States.Format('GuardDuty HIGH/CRITICAL finding: {}', $.detail.type)"
          "Subject.$"  = "States.Format('[{}] Security Alert: {}', $.detail.severity, $.detail.type)"
        }
        Next = "DetermineResourceType"
      }
      DetermineResourceType = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.detail.resource.resourceType"
            StringEquals  = "Instance"
            Next          = "IsolateEC2"
          },
          {
            Variable      = "$.detail.resource.resourceType"
            StringEquals  = "AccessKey"
            Next          = "RevokeCredentials"
          }
        ]
        Default = "LogResponseAction"
      }
      IsolateEC2 = {
        Type       = "Task"
        Resource   = aws_lambda_function.isolate_ec2.arn
        Next       = "LogResponseAction"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "LogResponseAction"
          ResultPath  = "$.error"
        }]
      }
      RevokeCredentials = {
        Type       = "Task"
        Resource   = aws_lambda_function.revoke_credentials.arn
        Next       = "LogResponseAction"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "LogResponseAction"
          ResultPath  = "$.error"
        }]
      }
      LogResponseAction = {
        Type = "Pass"
        End  = true
      }
    }
  })
}

# ── EventBridge rules ─────────────────────────────────────────────────────────

resource "aws_iam_role" "eventbridge" {
  name = "${var.prefix}-eventbridge-sfn-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge" {
  name = "start-state-machine"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.incident_response.arn
    }]
  })
}

resource "aws_cloudwatch_event_rule" "high_severity" {
  name        = "${var.prefix}-guardduty-high-${var.environment}"
  description = "Route HIGH and CRITICAL GuardDuty findings (severity >= 7) to Step Functions"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "high_severity_sfn" {
  rule     = aws_cloudwatch_event_rule.high_severity.name
  arn      = aws_sfn_state_machine.incident_response.arn
  role_arn = aws_iam_role.eventbridge.arn
}

resource "aws_cloudwatch_event_rule" "medium_severity" {
  name        = "${var.prefix}-guardduty-medium-${var.environment}"
  description = "Route MEDIUM GuardDuty findings (severity 4-6.9) to SNS for notification only"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 4, "<", 7] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "medium_severity_sns" {
  rule = aws_cloudwatch_event_rule.medium_severity.name
  arn  = var.alert_topic_arn
}
