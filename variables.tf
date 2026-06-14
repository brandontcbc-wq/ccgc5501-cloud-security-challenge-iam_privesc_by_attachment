#=====================================================
# CUSTOMIZABLE VARIABLES
# Modify these to adjust the scenario to your needs
#=====================================================

variable "profile" {
  description = "AWS CLI profile to use for deployment"
  type        = string
  default     = "default"
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "cgid" {
  description = "Unique CloudGoat ID for resource naming (random string)"
  type        = string
  default     = "abc123xyz"
}

variable "scenario_name" {
  description = "Name of the scenario for resource tagging"
  type        = string
  default     = "iam_privesc_by_attachment"
}

variable "cg_whitelist" {
  description = "List of IP addresses to whitelist for SSH access (CIDR format)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Change this to your IP!
}

variable "attacker_user_name" {
  description = "Name of the initial attacker IAM user"
  type        = string
  default     = "kerrigan"
}

variable "meek_role_name" {
  description = "Name of the low-privilege EC2 role"
  type        = string
  default     = "ec2-meek-role"
}

variable "mighty_role_name" {
  description = "Name of the high-privilege EC2 role (admin access)"
  type        = string
  default     = "ec2-mighty-role"
}

variable "target_server_name" {
  description = "Name of the target EC2 instance to be deleted"
  type        = string
  default     = "super-critical-security-server"
}

variable "instance_type" {
  description = "EC2 instance type for the target server"
  type        = string
  default     = "t2.micro"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# Customization options for difficulty adjustment
variable "hide_mighty_role" {
  description = "If true, adds extra obfuscation to the mighty role (harder difficulty)"
  type        = bool
  default     = false
}

variable "add_decoy_roles" {
  description = "Number of decoy IAM roles to create (0 = none, increases difficulty)"
  type        = number
  default     = 0
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail logging for detection practice"
  type        = bool
  default     = false
}
