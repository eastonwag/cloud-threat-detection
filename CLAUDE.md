# CLAUDE.md — Cloud Threat Detection & Automated Response Pipeline

## Purpose of This File

This file provides full context for a Claude Code session picking up where a prior planning conversation left off. Read this before doing anything. Supporting docs are in `/docs/`.

---

## Project Goal

Build a portfolio-grade AWS cloud threat detection and automated incident response pipeline — fully provisioned with Terraform — to demonstrate cloud security engineering skills for job applications targeting Cloud Security Engineer and Cloud Engineer roles.

### Why This Project Exists

The developer (Roony) is a System Administrator/Software Developer (~3 years) transitioning into cloud/security engineering. Key resume gaps being addressed by this project:
- Limited SIEM and threat detection exposure
- No hands-on GuardDuty / Security Hub work
- No automated incident response experience

This project directly fills those gaps while building on existing strengths: Terraform (prior ECS Fargate project), GitHub Actions CI/CD with OIDC, IAM/RBAC, Python, and infrastructure-as-code.

---

## Tech Stack

| Layer | Tool |
|---|---|
| Infrastructure provisioning | Terraform (modular structure) |
| Cloud provider | AWS |
| Log source 1 | AWS CloudTrail (multi-region) |
| Log source 2 | VPC Flow Logs |
| Detection | AWS GuardDuty + AWS Security Hub |
| Event routing | AWS EventBridge |
| Orchestration | AWS Step Functions |
| Response actions | AWS Lambda (Python) |
| Notification | AWS SNS |
| Visibility | CloudWatch Dashboards (primary), OpenSearch (optional) |
| CI/CD | GitHub Actions |
| State backend | S3 + DynamoDB (Terraform remote state) |
| Language | Python (Lambda), HCL (Terraform) |

---

## Repo Structure

```
cloud-threat-detection/
├── CLAUDE.md                    ← you are here
├── README.md                    ← user-facing project overview
├── modules/
│   ├── cloudtrail/              ← CloudTrail + KMS + S3 logging bucket
│   ├── guardduty/               ← GuardDuty detector + protections
│   ├── security-hub/            ← Security Hub + CIS + FSBP standards
│   ├── vpc/                     ← VPC + subnets + Flow Logs
│   ├── incident-response/       ← EventBridge + Step Functions + Lambda
│   └── alerting/                ← SNS topics + subscriptions
├── environments/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
├── lambda/
│   ├── isolate-ec2/
│   │   └── handler.py
│   └── revoke-credentials/
│       └── handler.py
├── docs/
│   ├── architecture.md          ← data flow, component diagram description
│   ├── project-plan.md          ← 6-phase implementation plan
│   ├── mitre-mapping.md         ← ATT&CK tactic/technique per finding type
│   └── decisions.md             ← key technical decisions and rationale
└── .github/
    └── workflows/
        └── terraform.yml        ← plan on PR, apply on merge to main
```

---

## Current Status

**Nothing has been built yet.** This is a greenfield project. The structure above is the target — it does not exist on disk yet beyond what is in this repo.

Start at **Phase 1** of the implementation plan in `docs/project-plan.md`.

---

## Key Architectural Decisions (Already Made — Do Not Revisit)

1. **Modular Terraform** — each AWS service gets its own module. No monolithic `main.tf`. Modules are called from `environments/dev/main.tf`.
2. **Multi-region CloudTrail** — not single-region. This is a deliberate real-world config choice.
3. **KMS encryption on S3 buckets** — all log buckets use SSE-KMS, not SSE-S3.
4. **Severity-based routing in EventBridge** — HIGH/CRITICAL findings trigger automated response via Step Functions; MEDIUM findings trigger SNS notification only.
5. **Least-privilege IAM** — every Lambda has its own role scoped to only the permissions it needs. Document the reason for each permission in comments.
6. **Quarantine security group pattern** — EC2 isolation uses a pre-created empty security group (no inbound/outbound), not security group rule deletion.
7. **No Kubernetes** — intentionally excluded. Not adding K8s just to check a box.
8. **OpenSearch is optional** — CloudWatch dashboards are the primary visibility layer. OpenSearch adds cost (~$1-2/day) and is only worth adding if budget allows and a full SIEM-like UI is needed for demo purposes.

---

## Terraform Conventions

- Use `terraform fmt` before every commit.
- All modules must have: `main.tf`, `variables.tf`, `outputs.tf`, `README.md`.
- Variable descriptions are mandatory — no bare `variable "x" {}` blocks.
- Tag all resources with at minimum:
  ```hcl
  tags = {
    Project     = "cloud-threat-detection"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
  ```
- Remote state backend is S3 + DynamoDB. The bootstrap bucket/table must be created manually before `terraform init` (Terraform cannot manage its own backend).
- Use `terraform.tfvars` for environment-specific values. Never hardcode account IDs or region.

---

## Lambda Conventions

- Runtime: Python 3.12
- All handlers follow the signature: `def handler(event, context)`
- Log every action taken using Python `logging` module (not `print`)
- Each function must handle and log exceptions — never let a Lambda silently fail
- Package dependencies with a `requirements.txt` per function; Terraform handles zip packaging

---

## IAM Philosophy

Every IAM role and policy created in this project should reflect least-privilege. When writing a policy, ask: "What is the minimum set of actions and resources this service needs to do its job?" Document the answer in a comment above the policy block. This is a deliberate portfolio signal — reviewers will look at IAM config.

---

## Cost Awareness

| Service | ~Daily Cost |
|---|---|
| GuardDuty | Free for 30 days, then ~$1-3/day |
| CloudTrail | ~$2 flat (first trail free) |
| Step Functions | Negligible |
| Lambda | Free tier |
| OpenSearch | ~$1-2/day (optional) |

**Target:** Run the full environment for 2 weeks to generate real findings, document everything, then `terraform destroy`. Total budget ~$40-60.

Run `terraform destroy` when done. Do not leave GuardDuty or OpenSearch running indefinitely.

---

## Testing Approach

- Use `aws guardduty create-sample-findings` to generate synthetic findings without needing a real attack.
- Verify EventBridge is routing correctly by checking CloudWatch Logs for the EventBridge target.
- Verify Step Functions execution in the console — check input/output at each state.
- For EC2 isolation: launch a test t2.micro, trigger a HIGH finding against it, confirm the quarantine SG is applied.

---

## Portfolio / Documentation Requirements

These are non-negotiable for the project to serve its job-search purpose:

1. **Architecture diagram** in `docs/architecture.md` — data flow from log generation → detection → response.
2. **MITRE ATT&CK mapping** in `docs/mitre-mapping.md` — each GuardDuty finding type handled maps to a tactic/technique.
3. **README.md** — problem statement, architecture overview, deploy instructions, how to test, known limitations.
4. **Inline comments in IAM policies** explaining permission rationale.

---

## What to Build First

Go to `docs/project-plan.md` → **Phase 1: Foundation**. Complete phases in order. Do not skip ahead — each phase has a checkpoint that validates the prior work before building on top of it.
