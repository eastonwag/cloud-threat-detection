# Module: security-hub

Enables Security Hub with CIS AWS Foundations Benchmark and AWS Foundational Security Best Practices standards, and subscribes to GuardDuty findings.

## Resources

- `aws_securityhub_account` — enables Security Hub in the account
- `aws_securityhub_standards_subscription` — CIS v1.2.0 + FSBP v1.0.0
- `aws_securityhub_product_subscription` — ingests GuardDuty findings

Must be deployed after GuardDuty (`depends_on = [module.guardduty]` in root module).
