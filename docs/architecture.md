# Architecture

## Overview

This system provides automated threat detection and incident response for an AWS environment. It ingests logs from multiple sources, detects threats using AWS-native services, routes findings by severity, and executes response playbooks automatically — all without human intervention for HIGH/CRITICAL findings.

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        LOG SOURCES                              │
│                                                                 │
│   AWS API Calls          VPC Network Traffic                    │
│   (all regions)          (all ENIs)                             │
│        │                       │                                │
│        ▼                       ▼                                │
│   CloudTrail             VPC Flow Logs                          │
│        │                       │                                │
│        └──────────┬────────────┘                                │
│                   │                                             │
│                   ▼                                             │
│          S3 Log Buckets (SSE-KMS encrypted)                     │
│          CloudWatch Logs (real-time stream)                     │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                     DETECTION LAYER                             │
│                                                                 │
│   GuardDuty ◄──── reads from S3 + CloudTrail + Flow Logs        │
│      │                                                          │
│      ├── S3 Protection                                          │
│      ├── EC2 Malware Protection                                 │
│      └── EKS Audit Log Monitoring                               │
│                                                                 │
│   Security Hub ◄── aggregates findings from GuardDuty           │
│      ├── CIS AWS Foundations Benchmark                          │
│      └── AWS Foundational Security Best Practices               │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    │  GuardDuty finding events
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                      EVENT ROUTING                              │
│                                                                 │
│                    EventBridge                                  │
│                        │                                        │
│              ┌─────────┴──────────┐                            │
│              │                    │                            │
│         severity >= 7        severity 4-6                      │
│         (HIGH/CRITICAL)       (MEDIUM)                         │
│              │                    │                            │
│              ▼                    ▼                            │
│       Step Functions           SNS Topic                       │
│       (auto-respond)       (notify only)                       │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                   RESPONSE PLAYBOOK                             │
│                  (Step Functions)                               │
│                                                                 │
│   EnrichFinding                                                 │
│        │                                                        │
│        ▼                                                        │
│   NotifySecurityTeam ──► SNS ──► Email/PagerDuty                │
│        │                                                        │
│        ▼                                                        │
│   DetermineResourceType                                         │
│        │                                                        │
│        ├── EC2 finding ──► IsolateEC2 Lambda                    │
│        │                   (apply quarantine SG, tag instance)  │
│        │                                                        │
│        ├── IAM finding ──► RevokeCredentials Lambda             │
│        │                   (attach deny-all inline policy)      │
│        │                                                        │
│        └── Other ──────── LogOnly                               │
│                                                                 │
│        ▼                                                        │
│   LogResponseAction ──► S3 (structured response record)         │
└─────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                      VISIBILITY                                 │
│                                                                 │
│   CloudWatch Dashboards                                         │
│      ├── Finding count by severity (7-day trend)                │
│      ├── Failed console logins (metric filter)                  │
│      ├── API calls from unusual regions (metric filter)         │
│      └── Rejected VPC traffic volume                            │
│                                                                 │
│   OpenSearch (optional)                                         │
│      ├── CloudTrail log index                                    │
│      ├── Top API callers dashboard                              │
│      └── Geographic call source visualization                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Responsibilities

### CloudTrail
- Captures all AWS API activity across all regions
- Delivers to S3 (persistent storage) and CloudWatch Logs (real-time)
- Log file validation enabled — detects tampering
- Encrypted with dedicated KMS key

### VPC Flow Logs
- Captures all network traffic at the ENI level
- Both ACCEPT and REJECT records (not just rejected)
- Delivers to S3

### GuardDuty
- Continuously analyzes CloudTrail, DNS logs, VPC Flow Logs, and S3 data events
- Machine learning-based anomaly detection + threat intelligence feeds
- Generates findings with severity 1-10 (LOW: 1-3.9, MEDIUM: 4-6.9, HIGH: 7-8.9, CRITICAL: 9-10)
- 30-day free trial on first enable per account

### Security Hub
- Aggregates findings from GuardDuty (and other sources)
- Runs continuous compliance checks against CIS and FSBP standards
- Provides a single pane for overall security posture

### EventBridge
- Receives GuardDuty finding events in real-time
- Routes by severity using event pattern matching
- No polling — event-driven, sub-minute latency

### Step Functions
- Orchestrates the full incident response workflow
- Provides execution history and audit trail built-in
- Handles retries and error states
- Defined in Amazon States Language (JSON)

### Lambda Functions
- `isolate-ec2`: Applies quarantine security group + tags to a flagged instance
- `revoke-credentials`: Attaches deny-all inline policy to a flagged IAM user
- Each function has its own least-privilege IAM role

### SNS
- Sends notifications for MEDIUM findings and for HIGH/CRITICAL findings after response is initiated
- Subscription can be email, Slack (via HTTP endpoint), or PagerDuty

---

## Security Decisions

| Decision | Rationale |
|---|---|
| SSE-KMS on all S3 buckets | Dedicated key per bucket; enables key policy auditing and rotation |
| Multi-region CloudTrail | Catches API activity in regions you're not actively using (common attacker tactic) |
| Log file validation on CloudTrail | Detects if logs are tampered with post-delivery |
| Quarantine SG (not delete SG) | Preserves instance for forensics while blocking traffic |
| Deny-all inline policy (not delete user) | Preserves IAM entity and its attached policies for forensics |
| Severity threshold of 7 for auto-response | Avoids noisy false-positive responses on LOW/MEDIUM findings |
| Separate IAM role per Lambda | Blast radius limitation — a compromised Lambda can only act within its role |


