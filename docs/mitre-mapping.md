# MITRE ATT&CK Mapping

Maps GuardDuty finding types handled by this project to MITRE ATT&CK tactics and techniques.

---

## EC2 Findings

| GuardDuty Finding Type | ATT&CK Tactic | ATT&CK Technique | ID | Response |
|---|---|---|---|---|
| `UnauthorizedAccess:EC2/SSHBruteForce` | Credential Access | Brute Force | T1110 | Isolate EC2 |
| `UnauthorizedAccess:EC2/RDPBruteForce` | Credential Access | Brute Force: Password Guessing | T1110.001 | Isolate EC2 |
| `Recon:EC2/PortProbeUnprotectedPort` | Discovery | Network Service Discovery | T1046 | Notify only |
| `Recon:EC2/Portscan` | Discovery | Network Service Discovery | T1046 | Notify only |
| `Trojan:EC2/BlackholeTraffic` | Command and Control | Traffic Signaling | T1205 | Isolate EC2 |
| `Trojan:EC2/DropPoint` | Exfiltration | Exfiltration Over C2 Channel | T1041 | Isolate EC2 |
| `CryptoCurrency:EC2/BitcoinTool.B` | Impact | Resource Hijacking | T1496 | Isolate EC2 |
| `Backdoor:EC2/C&CActivity.B` | Command and Control | Application Layer Protocol | T1071 | Isolate EC2 |
| `Backdoor:EC2/DenialOfService.Tcp` | Impact | Network Denial of Service | T1498 | Isolate EC2 |
| `UnauthorizedAccess:EC2/TorIPCaller` | Defense Evasion | Proxy: Multi-hop Proxy | T1090.003 | Notify only |

---

## IAM / Credential Findings

| GuardDuty Finding Type | ATT&CK Tactic | ATT&CK Technique | ID | Response |
|---|---|---|---|---|
| `UnauthorizedAccess:IAMUser/ConsoleLoginSuccess.B` | Initial Access | Valid Accounts: Cloud Accounts | T1078.004 | Revoke credentials |
| `UnauthorizedAccess:IAMUser/MaliciousIPCaller` | Execution | User Execution | T1204 | Revoke credentials |
| `UnauthorizedAccess:IAMUser/TorIPCaller` | Defense Evasion | Proxy: Multi-hop Proxy | T1090.003 | Revoke credentials |
| `CredentialAccess:IAMUser/AnomalousBehavior` | Credential Access | Steal Application Access Token | T1528 | Revoke credentials |
| `PrivilegeEscalation:IAMUser/AnomalousBehavior` | Privilege Escalation | Valid Accounts: Cloud Accounts | T1078.004 | Revoke credentials |
| `Persistence:IAMUser/AnomalousBehavior` | Persistence | Account Manipulation | T1098 | Revoke credentials |
| `Impact:IAMUser/AnomalousBehavior` | Impact | Account Access Removal | T1531 | Revoke credentials |
| `Stealth:IAMUser/CloudTrailLoggingDisabled` | Defense Evasion | Impair Defenses: Disable Cloud Logs | T1562.008 | Revoke credentials + alert |
| `Stealth:IAMUser/PasswordPolicyChange` | Defense Evasion | Modify Authentication Process | T1556 | Revoke credentials |
| `Discovery:IAMUser/AnomalousBehavior` | Discovery | Cloud Infrastructure Discovery | T1580 | Notify only |

---

## S3 Findings

| GuardDuty Finding Type | ATT&CK Tactic | ATT&CK Technique | ID | Response |
|---|---|---|---|---|
| `UnauthorizedAccess:S3/MaliciousIPCaller.Custom` | Exfiltration | Transfer Data to Cloud Account | T1537 | Notify only |
| `Discovery:S3/MaliciousIPCaller` | Discovery | Cloud Storage Object Discovery | T1619 | Notify only |
| `Exfiltration:S3/ObjectRead.Unusual` | Exfiltration | Transfer Data to Cloud Account | T1537 | Notify only |
| `Policy:S3/BucketBlockPublicAccessDisabled` | Defense Evasion | Impair Defenses | T1562 | Notify + alert |
| `Stealth:S3/ServerAccessLoggingDisabled` | Defense Evasion | Impair Defenses: Disable Cloud Logs | T1562.008 | Notify + alert |

---

### Extending this project
For each new finding type you add response logic for:
1. Look up the finding in GuardDuty docs
2. Map it to the ATT&CK technique
3. Add it to this table
4. Note the response action and why

---

## ATT&CK Tactic Reference

| Tactic | What It Means in Cloud Context |
|---|---|
| Initial Access | Attacker gaining first foothold (stolen creds, phishing) |
| Persistence | Attacker ensuring they can return (new IAM user, backdoor) |
| Privilege Escalation | Attacker gaining higher permissions |
| Defense Evasion | Attacker hiding activity (disabling logs, using Tor) |
| Credential Access | Attacker stealing or brute-forcing credentials |
| Discovery | Attacker mapping your environment |
| Lateral Movement | Attacker moving between resources/accounts |
| Exfiltration | Attacker stealing data |
| Impact | Attacker destroying, encrypting, or disrupting resources |
| Command and Control | Attacker communicating with compromised resources |
