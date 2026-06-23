# Module: guardduty

Enables GuardDuty with S3 Protection, EC2 Malware Protection, and Kubernetes Audit Log monitoring.

## Resources

- `aws_guardduty_detector` — detector with all three protection types enabled

## Usage

```hcl
module "guardduty" {
  source      = "../../modules/guardduty"
  prefix      = var.prefix
  environment = var.environment
}
```

## Testing

```bash
DETECTOR_ID=$(terraform output -raw guardduty_detector_id)
aws guardduty create-sample-findings \
  --detector-id $DETECTOR_ID \
  --finding-types \
    "UnauthorizedAccess:EC2/SSHBruteForce" \
    "UnauthorizedAccess:IAMUser/ConsoleLoginSuccess.B"
```
