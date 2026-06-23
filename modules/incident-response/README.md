# Module: incident-response

Wires together EventBridge routing, Step Functions orchestration, and Lambda response actions into a complete automated incident response playbook.

## What it creates

- **Quarantine security group** — empty SG (no rules) applied to EC2 instances on isolation
- **Lambda: isolate-ec2** — replaces instance SGs with quarantine SG, tags instance `QUARANTINED`
- **Lambda: revoke-credentials** — attaches deny-all inline policy to flagged IAM user
- **Step Functions state machine** — orchestrates: notify → classify → isolate/revoke → log
- **EventBridge rule (HIGH/CRITICAL)** — severity >= 7 → Step Functions
- **EventBridge rule (MEDIUM)** — severity 4–6.9 → SNS notify only

## Playbook flow

```
GuardDuty finding (severity >= 7)
  └─► EventBridge
        └─► Step Functions
              ├─ NotifySecurityTeam (SNS)
              ├─ DetermineResourceType
              │     ├─ EC2  → IsolateEC2 Lambda
              │     ├─ IAM  → RevokeCredentials Lambda
              │     └─ Other → pass through
              └─ LogResponseAction
```

See [docs/mitre-mapping.md](../../docs/mitre-mapping.md) for the ATT&CK technique behind each finding type.
