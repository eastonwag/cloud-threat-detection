# Phase 3 — GuardDuty detector with S3, Malware, and EKS protections
# See docs/project-plan.md Step 7 for details.

resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }
}
