# Module: cloudtrail

Creates a multi-region CloudTrail trail with KMS encryption, S3 log delivery, and CloudWatch Logs integration.

## Resources

- `aws_kms_key` + `aws_kms_alias` — dedicated encryption key with CloudTrail-scoped key policy
- `aws_s3_bucket` — log destination with versioning, SSE-KMS, public access block, and lifecycle rules
- `aws_s3_bucket_policy` — grants CloudTrail `s3:PutObject` (required; CloudTrail silently fails without it)
- `aws_cloudwatch_log_group` — real-time log stream for metric filters and Logs Insights queries
- `aws_cloudtrail` — multi-region trail with log file validation enabled

## Usage

```hcl
module "cloudtrail" {
  source      = "../../modules/cloudtrail"
  prefix      = var.prefix
  environment = var.environment
  aws_region  = var.aws_region
}
```
