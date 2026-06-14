#=====================================================
# OUTPUTS - SCENARIO START INFORMATION
# These values are provided to the attacker to begin
#=====================================================

output "cloudgoat_output_aws_account_id" {
  description = "AWS Account ID where the scenario is deployed"
  value       = data.aws_caller_identity.current.account_id
}

output "cloudgoat_output_kerrigan_access_key_id" {
  description = "Access Key ID for the Kerrigan user (starting credentials)"
  value       = aws_iam_access_key.kerrigan.id
}

output "cloudgoat_output_kerrigan_secret_key" {
  description = "Secret Access Key for the Kerrigan user"
  value       = aws_iam_access_key.kerrigan.secret
  sensitive   = true
}

output "cloudgoat_output_region" {
  description = "AWS region where resources are deployed"
  value       = var.region
}

output "scenario_cgid" {
  description = "CloudGoat unique identifier for this scenario instance"
  value       = var.cgid
}

output "target_instance_id" {
  description = "Instance ID of the target server (for verification)"
  value       = aws_instance.target.id
}

output "target_instance_name" {
  description = "Name tag of the target server"
  value       = "cg-${var.target_server_name}-${local.resource_suffix}"
}

output "vpc_id" {
  description = "VPC ID for the scenario"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Subnet ID for EC2 instances"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Security Group ID for EC2 instances"
  value       = aws_security_group.ec2.id
}

output "instance_profile_name" {
  description = "Name of the exploitable instance profile"
  value       = aws_iam_instance_profile.meek.name
}

output "meek_role_name" {
  description = "Name of the low-privilege role"
  value       = aws_iam_role.meek.name
}

output "mighty_role_name" {
  description = "Name of the high-privilege role (target for escalation)"
  value       = aws_iam_role.mighty.name
}

#=====================================================
# START.TXT CONTENT
# Generates the content for the scenario start file
#=====================================================

output "start_file_content" {
  description = "Content to write to start.txt"
  value       = <<-EOT
    ╔═══════════════════════════════════════════════════════════════╗
    ║     CloudGoat: IAM Privilege Escalation by Attachment         ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║  Scenario ID: ${var.cgid}
    ║  Region: ${var.region}
    ║  Account ID: ${data.aws_caller_identity.current.account_id}
    ╠═══════════════════════════════════════════════════════════════╣
    ║  STARTING CREDENTIALS (Kerrigan User)                         ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║  Access Key ID: ${aws_iam_access_key.kerrigan.id}
    ║  Secret Key: ${aws_iam_access_key.kerrigan.secret}
    ╠═══════════════════════════════════════════════════════════════╣
    ║  OBJECTIVE                                                     ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║  Delete the EC2 instance named:                                ║
    ║  cg-${var.target_server_name}-${local.resource_suffix}
    ║                                                                ║
    ║  Target Instance ID: ${aws_instance.target.id}
    ╚═══════════════════════════════════════════════════════════════╝
    
    HINT: You have limited IAM permissions, but can you find a way to 
    leverage EC2 instance profiles to gain higher privileges?
  EOT
  sensitive   = true
}

# Create start.txt file
resource "local_file" "start_txt" {
  content  = <<-EOT
    CloudGoat Scenario: IAM Privilege Escalation by Attachment
    ===========================================================
    
    Scenario ID: ${var.cgid}
    Region: ${var.region}
    Account ID: ${data.aws_caller_identity.current.account_id}
    
    STARTING CREDENTIALS (Kerrigan User)
    -------------------------------------
    Access Key ID: ${aws_iam_access_key.kerrigan.id}
    Secret Key: ${aws_iam_access_key.kerrigan.secret}
    
    OBJECTIVE
    ---------
    Delete the EC2 instance named: cg-${var.target_server_name}-${local.resource_suffix}
    Target Instance ID: ${aws_instance.target.id}
    
    Configure your AWS CLI:
    $ aws configure --profile kerrigan
    
    Good luck!
  EOT
  filename = "${path.module}/start.txt"
}
