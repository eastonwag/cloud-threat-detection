# Technical Decisions & Rationale

Documents the key decisions made during planning so they aren't relitigated in future sessions. If you're considering changing one of these, read the rationale first.

---

## Project Scope

**Decision:** Build cloud threat detection + automated incident response, not a CTF writeup or basic "security best practices" repo.

**Rationale:** The developer's resume gap is SIEM and threat detection exposure. This project directly fills that gap with AWS-native tooling (GuardDuty, Security Hub, EventBridge, Step Functions) that appears in real cloud security job descriptions. CTF writeups and checklist repos are weak portfolio signals for cloud security engineering roles.

---

## Terraform Modular Structure

**Decision:** Each AWS service gets its own Terraform module. No monolithic `main.tf`.

**Rationale:** Real organizations structure Terraform this way. A flat `main.tf` with 500 lines is a signal that someone learned from a tutorial, not production experience. Modules also demonstrate understanding of reusability, separation of concerns, and how Terraform scales across teams.

---

## Multi-Region CloudTrail

**Decision:** Enable CloudTrail as a multi-region trail, not single-region.

**Rationale:** Attackers commonly operate in regions that organizations don't actively monitor. Single-region CloudTrail misses API activity in unused regions entirely. Multi-region is the correct production configuration and signals awareness of this attack pattern.

---

## SSE-KMS Over SSE-S3

**Decision:** All S3 buckets use SSE-KMS with dedicated KMS keys, not the default SSE-S3.

**Rationale:** SSE-KMS enables key policy control, CloudTrail auditing of key usage, and key rotation. SSE-S3 provides encryption but no visibility into who accessed the key. For security log buckets specifically, key usage auditing is operationally important.

---

## Quarantine Security Group (Not Delete)

**Decision:** EC2 isolation uses a pre-created empty security group (no rules = no traffic), not deletion of existing security group rules.

**Rationale:** Deleting security group rules is destructive and non-reversible without knowing the original state. Replacing with a quarantine SG is reversible, preserves the original SG for forensic review, and doesn't risk breaking other resources sharing that SG. Also avoids a race condition where rules might be partially deleted.

---

## Deny-All Inline Policy (Not Delete IAM Entity)

**Decision:** Credential revocation attaches a deny-all inline policy, not deletion of the user or role.

**Rationale:** Deleting an IAM user destroys forensic evidence (access keys, attached policies, group memberships). An inline deny-all is immediately effective (explicit Deny overrides all Allow) while preserving the entity and its configuration for incident investigation. The entity can be deleted after forensics if needed.

---

## Severity Threshold of 7 for Automated Response

**Decision:** Automated playbook (isolation/revocation) fires on findings with severity >= 7 (HIGH). MEDIUM findings (4-6.9) get notification only.

**Rationale:** Automating response to MEDIUM findings produces noisy false positives — many MEDIUM findings are benign or context-dependent. HIGH findings represent confirmed or near-certain threats where the cost of a false positive (temporary instance isolation) is lower than the cost of missing a true positive. This is a deliberate operational tradeoff, not an oversight.

---

## Separate IAM Role Per Lambda

**Decision:** Each Lambda function has its own IAM execution role, scoped to only the permissions that specific function needs.

**Rationale:** Least-privilege blast radius limitation. If a Lambda function is compromised or has a bug that can be exploited, its role defines the maximum damage it can do. A shared role across all Lambda functions would mean a compromised isolate-ec2 function could also delete IAM users, read S3 buckets, etc.

---

## No Kubernetes

**Decision:** Kubernetes/EKS is not included in this project.

**Rationale:** Adding K8s without deep knowledge produces a shallow portfolio piece that will be exposed in interviews. The developer's current K8s experience gap means adding it here would be tutorial-following, not genuine understanding. It's better to go deep on what's here than broad and shallow. K8s should be added to the portfolio when there's genuine hands-on depth to back it up.

---

## OpenSearch Is Optional

**Decision:** CloudWatch dashboards are the primary visibility layer. OpenSearch is additive and optional.

**Rationale:** OpenSearch costs $1-2/day and adds significant complexity. CloudWatch Logs Insights covers most querying needs for free. OpenSearch makes sense if the developer wants a full SIEM-like UI for demo purposes or has budget to spare. It should not be the first thing built.

---

## GitHub Actions CI/CD

**Decision:** GitHub Actions runs `terraform plan` on PR and `terraform apply` on merge to main.

**Rationale:** The developer already has GitHub Actions experience from the ECS Fargate project (OIDC auth). Reusing this pattern is consistent and demonstrates that infrastructure changes go through review before apply — standard practice in real organizations. Also makes the repo look production-grade to reviewers.

---

## AWS Region

**Decision:** Primary region is `us-east-1`.

**Rationale:** Lowest cost, widest service availability, familiar. No strong reason to use a different region for a portfolio project.
