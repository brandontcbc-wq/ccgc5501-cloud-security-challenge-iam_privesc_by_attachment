#=====================================================
# CloudGoat-style IAM Privilege Escalation by Attachment
# Vulnerable by Design - For Educational Purposes Only
#=====================================================
# 
# Scenario: An attacker starts as IAM user "Kerrigan" with limited
# permissions. They can leverage instance-profile-attachment permissions
# to create a new EC2 instance with elevated privileges, gaining admin
# access to delete the "super-critical-security-server".
#
# Customize: Modify variables.tf to adjust the scenario parameters
#=====================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  profile = var.profile
  region  = var.region
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get current region
data "aws_region" "current" {}

# Get the latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  # Unique identifier for resources
  resource_suffix = "${var.scenario_name}-${var.cgid}"
}
