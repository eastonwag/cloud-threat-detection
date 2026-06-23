# Module: vpc

Creates a VPC with public and private subnets across two AZs, with VPC Flow Logs capturing ALL traffic to S3.

## Resources

- `aws_vpc`, `aws_subnet` (public + private × 2 AZs), `aws_internet_gateway`
- `aws_s3_bucket` — flow log destination with SSE and public access block
- `aws_flow_log` — captures ACCEPT + REJECT for full visibility
- `aws_iam_role` — allows VPC Flow Logs service to write to S3

## Usage

```hcl
module "vpc" {
  source      = "../../modules/vpc"
  prefix      = var.prefix
  environment = var.environment
  aws_region  = var.aws_region
}
```
