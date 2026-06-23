# Cloud Threat Detection & Automated Response Pipeline

> AWS-native threat detection and incident response — fully provisioned with Terraform.

## Overview

This project implements an end-to-end cloud security monitoring system on AWS. It ingests API activity (CloudTrail) and network traffic (VPC Flow Logs), detects threats using GuardDuty and Security Hub, routes findings by severity via EventBridge, and automatically executes incident response playbooks through Step Functions and Lambda — all without manual intervention for HIGH/CRITICAL findings.

**Built to demonstrate:** Cloud security engineering depth — SIEM concepts, AWS-native threat detection, automated incident response, and infrastructure-as-code.

---


## Tech Stack

- **Infrastructure:** Terraform (modular)
- **Detection:** AWS GuardDuty, AWS Security Hub
- **Log sources:** AWS CloudTrail (multi-region), VPC Flow Logs
- **Event routing:** AWS EventBridge
- **Response orchestration:** AWS Step Functions
- **Response actions:** AWS Lambda (Python 3.12)
- **Notification:** AWS SNS

---

## Prerequisites

- AWS account (dedicated recommended — GuardDuty has a 30-day free trial per account)
- Terraform >= 1.6.0
- AWS CLI configured
- Python 3.12 (for Lambda development)
- Bootstrap resources created manually (see Deployment)

---

## Deployment

### 1. Bootstrap remote state (one time)

```bash
# Create S3 state bucket
aws s3api create-bucket \
  --bucket <your-prefix>-tfstate \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket <your-prefix>-tfstate \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket <your-prefix>-tfstate \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Configure variables

```bash
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Initialize and apply

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

---

## Testing

Generate synthetic GuardDuty findings without a real attack:

```bash
# Get your detector ID
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)

# Generate sample findings
aws guardduty create-sample-findings \
  --detector-id $DETECTOR_ID \
  --finding-types \
    "UnauthorizedAccess:EC2/SSHBruteForce" \
    "UnauthorizedAccess:IAMUser/ConsoleLoginSuccess.B" \
    "Recon:EC2/PortProbeUnprotectedPort"
```

After running this:
1. Check GuardDuty console for findings
2. Check EventBridge — HIGH findings should trigger Step Functions
3. Check Step Functions console — watch execution progress through states
4. Check CloudWatch dashboard for updated metrics

---

## Response Playbook

When a HIGH/CRITICAL GuardDuty finding fires:

1. **Enrich** — Lambda looks up additional context about the affected resource
2. **Notify** — SNS sends immediate alert to security team
3. **Contain** — Based on resource type:
   - EC2: Quarantine security group applied, instance tagged `QUARANTINED`
   - IAM: Deny-all inline policy attached to user/role
4. **Log** — Structured response record written to S3 for audit trail

MEDIUM findings notify only — no automated containment.

See [`docs/mitre-mapping.md`](docs/mitre-mapping.md) for the MITRE ATT&CK techniques each finding type maps to.

---

## Estimated Cost

| Service | Cost |
|---|---|
| GuardDuty (after 30-day trial) | ~$1-3/day |
| Step Functions | Negligible |
| Lambda | Free tier |
| **Total (2-week run)** | **~$20-45** |

---

## Teardown

```bash
cd environments/dev
terraform destroy
```

Then manually disable GuardDuty and delete the bootstrap S3 bucket and DynamoDB table.

> **Note:** GuardDuty must be explicitly disabled — `terraform destroy` alone may not stop billing.

---

## Known Limitations

- Single AWS account (no AWS Organizations setup — that would enable GuardDuty delegated admin)
- No Kubernetes/EKS monitoring (intentionally excluded)
- Step Functions response playbook handles EC2 and IAM findings; S3 findings notify only
- OpenSearch not included (CloudWatch Logs Insights used instead)

---

## Future Improvements

- Multi-account setup with AWS Organizations
- EKS threat detection
- Automated forensic snapshot before EC2 isolation
- Slack/PagerDuty integration via SNS HTTP endpoint
- OpenSearch SIEM dashboard
- Athena queries over CloudTrail S3 logs
