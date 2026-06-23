# Project Implementation Plan

Six phases, in order. Each phase ends with a checkpoint. Do not proceed to the next phase until the checkpoint passes.

---

## Phase 1 — Foundation (Est. 1-2 days)

### Goals
- AWS account configured and ready
- Terraform remote state backend bootstrapped
- Repo structure in place
- Provider and backend configured

### Steps

**1. AWS account setup**
- Use a dedicated AWS account or at minimum an isolated IAM user with programmatic access
- Do not build this in an account with production resources
- GuardDuty has a 30-day free trial on first enable — plan accordingly

**2. Bootstrap Terraform remote state (manual — do this before `terraform init`)**
- Create S3 bucket: `<your-prefix>-tfstate` with versioning and SSE enabled
- Create DynamoDB table: `terraform-lock` with partition key `LockID` (String)
- These must be created manually (via console or AWS CLI) — Terraform cannot manage its own backend

**3. Initialize repo structure**
- Create the directory layout from `CLAUDE.md`
- Initialize git, create `.gitignore` (exclude `.terraform/`, `*.tfvars` if they contain secrets, `*.tfstate`)

**4. Configure Terraform provider and backend**
```hcl
# environments/dev/main.tf
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "<your-prefix>-tfstate"
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
```

### Checkpoint
- `terraform init` completes without error
- `terraform plan` runs (nothing to create yet, that's fine)
- State file appears in S3 after first apply

---

## Phase 2 — Logging Infrastructure (Est. 2-3 days)

### Goals
- CloudTrail capturing API activity across all regions
- VPC with Flow Logs enabled
- All logs landing in encrypted S3 buckets

### Steps

**5. CloudTrail module (`modules/cloudtrail/`)**

Key resources:
- `aws_kms_key` + `aws_kms_alias` — dedicated key for log encryption
- `aws_s3_bucket` — log destination with:
  - `aws_s3_bucket_versioning` — enabled
  - `aws_s3_bucket_server_side_encryption_configuration` — SSE-KMS
  - `aws_s3_bucket_public_access_block` — all four blocks set to true
  - `aws_s3_bucket_lifecycle_configuration` — transition to IA after 30 days, expire after 90
  - `aws_s3_bucket_logging` — access logs to a separate bucket
- `aws_cloudtrail` — multi-region, include global service events, enable log file validation
- `aws_cloudwatch_log_group` — for real-time CloudTrail → CloudWatch integration

Important: The S3 bucket policy must explicitly allow CloudTrail to write. This is a common gotcha — CloudTrail will silently fail without it.

**6. VPC module (`modules/vpc/`)**

Key resources:
- `aws_vpc`
- `aws_subnet` (public + private, at least 2 AZs)
- `aws_internet_gateway`
- `aws_flow_log` — capture ALL traffic (not just REJECT), destination: S3
- `aws_iam_role` — Flow Logs needs a role to write to CloudWatch if using CW destination

### Checkpoint
- `terraform apply` succeeds
- CloudTrail is active and set to multi-region in AWS console
- Make a few AWS CLI calls, wait 5 minutes, confirm log files appear in S3
- Flow log records visible in S3 or CloudWatch

---

## Phase 3 — Detection Layer (Est. 2-3 days)

### Goals
- GuardDuty enabled with all protections active
- Security Hub enabled with CIS and FSBP standards
- EventBridge routing findings to the right targets by severity

### Steps

**7. GuardDuty module (`modules/guardduty/`)**

Key resources:
- `aws_guardduty_detector` — enable with `enable = true`
- Configure additional protections:
  - `aws_guardduty_detector_feature` for S3 protection, EKS Audit Log protection, Malware Protection
- Note: GuardDuty findings appear within minutes of a suspicious API call

**8. Security Hub module (`modules/security-hub/`)**

Key resources:
- `aws_securityhub_account`
- `aws_securityhub_standards_subscription` — add both:
  - CIS AWS Foundations Benchmark: `arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0`
  - AWS Foundational Security Best Practices: `arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0`
- `aws_securityhub_product_subscription` — subscribe to GuardDuty findings

**9. EventBridge routing rules (`modules/incident-response/`)**

Two rules:
- HIGH/CRITICAL findings → Step Functions (automated response)
- MEDIUM findings → SNS (notification only)

```hcl
# Rule for HIGH/CRITICAL
resource "aws_cloudwatch_event_rule" "high_severity_findings" {
  name        = "guardduty-high-severity"
  description = "Route HIGH and CRITICAL GuardDuty findings to Step Functions"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}
```

### Checkpoint
- Run: `aws guardduty create-sample-findings --detector-id <id> --finding-types "UnauthorizedAccess:EC2/SSHBruteForce"`
- Confirm finding appears in GuardDuty console
- Confirm EventBridge rule triggers (check CloudWatch metrics for the rule)
- Security Hub shows findings being ingested from GuardDuty

---

## Phase 4 — Incident Response Automation (Est. 3-4 days)

**This is the most technically impressive phase. Do not shortcut it.**

### Goals
- Lambda functions that take concrete remediation actions
- Step Functions orchestrating a full response playbook
- All actions logged

### Steps

**10. Lambda functions (`lambda/`)**

**`isolate-ec2/handler.py`**
```python
import boto3
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client('ec2')

def handler(event, context):
    """
    Isolates an EC2 instance by replacing its security groups
    with a pre-created quarantine security group (no inbound/outbound rules).
    """
    try:
        instance_id = event['detail']['resource']['instanceDetails']['instanceId']
        quarantine_sg_id = os.environ['QUARANTINE_SG_ID']

        logger.info(f"Isolating instance {instance_id}")

        ec2.modify_instance_attribute(
            InstanceId=instance_id,
            Groups=[quarantine_sg_id]
        )

        ec2.create_tags(
            Resources=[instance_id],
            Tags=[
                {'Key': 'SecurityStatus', 'Value': 'QUARANTINED'},
                {'Key': 'QuarantineReason', 'Value': 'GuardDuty HIGH finding - automated response'}
            ]
        )

        logger.info(f"Instance {instance_id} successfully quarantined")
        return {'status': 'success', 'instance_id': instance_id}

    except Exception as e:
        logger.error(f"Failed to isolate instance: {str(e)}")
        raise
```

**`revoke-credentials/handler.py`**
```python
import boto3
import logging
import json
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

iam = boto3.client('iam')

DENY_ALL_POLICY = json.dumps({
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Deny",
        "Action": "*",
        "Resource": "*"
    }]
})

def handler(event, context):
    """
    Attaches a deny-all inline policy to a flagged IAM entity.
    Does not delete the user/role — preserves forensic state.
    """
    try:
        principal = event['detail']['resource']['accessKeyDetails']
        user_name = principal.get('userName')
        
        if not user_name or user_name == 'ANONYMOUS_PRINCIPAL':
            logger.warning("No valid IAM user to revoke — skipping")
            return {'status': 'skipped', 'reason': 'no_valid_principal'}

        policy_name = f"SECURITY-DENY-ALL-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"

        logger.info(f"Revoking credentials for user: {user_name}")

        iam.put_user_policy(
            UserName=user_name,
            PolicyName=policy_name,
            PolicyDocument=DENY_ALL_POLICY
        )

        logger.info(f"Deny-all policy applied to {user_name}")
        return {'status': 'success', 'user_name': user_name, 'policy_name': policy_name}

    except Exception as e:
        logger.error(f"Failed to revoke credentials: {str(e)}")
        raise
```

**11. Step Functions state machine**

Define in Amazon States Language (JSON). Terraform resource: `aws_sfn_state_machine`.

States:
1. `EnrichFinding` — Lambda: look up additional context (instance details, user info)
2. `NotifySecurityTeam` — SNS: send finding details immediately
3. `DetermineResourceType` — Choice state: EC2 vs IAM vs other
4. `IsolateEC2` — Lambda: isolate-ec2 handler
5. `RevokeCredentials` — Lambda: revoke-credentials handler
6. `LogResponseAction` — Lambda: write structured response record to S3
7. `Done`

**12. IAM roles for each Lambda**

Each Lambda gets its own role. Example for isolate-ec2:
```hcl
# Only the permissions needed to modify instance attributes and create tags.
# ec2:DescribeInstances needed to validate instance exists before acting.
resource "aws_iam_role_policy" "isolate_ec2_policy" {
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
        # Needed to tag the instance with quarantine metadata
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = "arn:aws:ec2:*:*:instance/*"
      }
    ]
  })
}
```

### Checkpoint
- Manually invoke isolate-ec2 Lambda with a synthetic event payload
- Confirm target EC2 instance has quarantine SG applied and tags set
- Trigger a sample GuardDuty HIGH finding and watch the full Step Functions execution in the console
- Confirm each state transitions correctly

---

## Phase 5 — Visibility (Est. 1-2 days)

### Goals
- CloudWatch dashboards showing security posture at a glance
- (Optional) OpenSearch ingesting CloudTrail logs for SIEM-like querying

### Steps

**13. CloudWatch dashboards**

Build a dashboard with:
- GuardDuty finding count by severity (last 7 days)
- CloudTrail: failed console logins (metric filter on CloudWatch Logs)
- CloudTrail: unusual API calls from unknown regions (metric filter)
- VPC Flow Logs: rejected traffic volume over time
- Step Functions: execution success/failure count

Metric filters go in the CloudTrail module since they reference the CloudWatch log group.

**14. OpenSearch (optional)**

Only add if budget allows (~$1-2/day). A Lambda subscribed to the CloudTrail CloudWatch log group ships logs to OpenSearch. Build a simple index pattern and dashboard showing:
- Top API callers
- Error rate over time
- Geographic source of API calls

If skipping OpenSearch, CloudWatch Logs Insights can answer many of the same queries for free.

### Checkpoint
- CloudWatch dashboard renders with real data
- Metric filters are firing (generate some failed logins to test)

---

## Phase 6 — Documentation (Est. 2 days)

**Do not skip or rush this phase. It is 40% of the portfolio value.**

### Steps

**15. Architecture diagram**
- Use Draw.io (free, exports to PNG/SVG)
- Show: CloudTrail → S3 → (GuardDuty reads) → EventBridge → Step Functions → Lambda → (EC2/IAM)
- Include SNS notification path
- Export as PNG and embed in `docs/architecture.md` and `README.md`

**16. MITRE ATT&CK mapping**
- See `docs/mitre-mapping.md` for the template
- Complete the mapping for every GuardDuty finding type your response pipeline handles

**17. README.md**
Sections:
- Overview (what it does, why it exists)
- Architecture diagram
- Prerequisites
- Deployment (step by step)
- Testing (how to generate sample findings)
- Response playbook (what happens when a HIGH finding fires)
- Known limitations
- Estimated cost
- Teardown (`terraform destroy` instructions)

**18. Teardown**
- Run `terraform destroy` to avoid ongoing charges
- Confirm GuardDuty is disabled (it will keep charging even after destroy if not explicitly disabled)
- Delete the bootstrap S3 bucket and DynamoDB table manually

---

## Phase Summary

| Phase | Focus | Est. Time |
|---|---|---|
| 1 | Foundation & Terraform setup | 1-2 days |
| 2 | CloudTrail + VPC Flow Logs | 2-3 days |
| 3 | GuardDuty + Security Hub + EventBridge | 2-3 days |
| 4 | Lambda + Step Functions (incident response) | 3-4 days |
| 5 | CloudWatch dashboards + optional OpenSearch | 1-2 days |
| 6 | Documentation + teardown | 2 days |
| **Total** | | **~11-16 days** |
