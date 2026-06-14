#=====================================================
# IAM - ATTACKER USER (KERRIGAN)
# This is the starting point for the attacker
#=====================================================

resource "aws_iam_user" "kerrigan" {
  name = "cg-${var.attacker_user_name}-${local.resource_suffix}"
  path = "/"

  tags = {
    Name     = "cg-${var.attacker_user_name}-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
  }
}

resource "aws_iam_access_key" "kerrigan" {
  user = aws_iam_user.kerrigan.name
}

# Policy for the attacker user - limited but exploitable permissions
resource "aws_iam_user_policy" "kerrigan" {
  name = "cg-${var.attacker_user_name}-policy-${local.resource_suffix}"
  user = aws_iam_user.kerrigan.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 Read permissions
      {
        Sid    = "EC2ReadAccess"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeIamInstanceProfileAssociations"
        ]
        Resource = "*"
      },
      # EC2 Instance creation - THE VULNERABILITY
      {
        Sid    = "EC2RunInstances"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances"
        ]
        Resource = "*"
      },
      # EC2 Key pair management
      {
        Sid    = "EC2KeyPairManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateKeyPair",
          "ec2:DeleteKeyPair"
        ]
        Resource = "*"
      },
      # EC2 Tagging for created resources
      {
        Sid    = "EC2CreateTags"
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "RunInstances"
          }
        }
      },
      # IAM Instance Profile manipulation - THE KEY VULNERABILITY
      {
        Sid    = "IAMInstanceProfileManipulation"
        Effect = "Allow"
        Action = [
          "iam:ListInstanceProfiles",
          "iam:ListRoles",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile"
        ]
        Resource = "*"
      },
      # EC2 Instance Profile Association
      {
        Sid    = "EC2InstanceProfileAssociation"
        Effect = "Allow"
        Action = [
          "ec2:AssociateIamInstanceProfile",
          "ec2:DisassociateIamInstanceProfile"
        ]
        Resource = "*"
      },
      # IAM PassRole for EC2
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.meek.arn,
          aws_iam_role.mighty.arn
        ]
      },
      # STS for identity verification
      {
        Sid    = "STSGetCallerIdentity"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

#=====================================================
# IAM - MEEK ROLE (LOW PRIVILEGE)
# Initial role attached to the instance profile
#=====================================================

resource "aws_iam_role" "meek" {
  name = "cg-${var.meek_role_name}-${local.resource_suffix}"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name     = "cg-${var.meek_role_name}-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
  }
}

resource "aws_iam_role_policy" "meek" {
  name = "cg-${var.meek_role_name}-policy-${local.resource_suffix}"
  role = aws_iam_role.meek.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LimitedS3Access"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Resource = "*"
      },
      {
        Sid    = "STSGetCallerIdentity"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

#=====================================================
# IAM - MIGHTY ROLE (HIGH PRIVILEGE - ADMIN)
# This is what the attacker wants to escalate to
#=====================================================

resource "aws_iam_role" "mighty" {
  name = "cg-${var.mighty_role_name}-${local.resource_suffix}"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name     = "cg-${var.mighty_role_name}-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
  }
}

resource "aws_iam_role_policy" "mighty" {
  name = "cg-${var.mighty_role_name}-policy-${local.resource_suffix}"
  role = aws_iam_role.mighty.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AdministratorAccess"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

#=====================================================
# IAM INSTANCE PROFILE
# Container for the role - can be swapped by attacker
#=====================================================

resource "aws_iam_instance_profile" "meek" {
  name = "cg-ec2-meek-instance-profile-${local.resource_suffix}"
  role = aws_iam_role.meek.name

  tags = {
    Name     = "cg-ec2-meek-instance-profile-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
  }
}

#=====================================================
# OPTIONAL: DECOY ROLES (for increased difficulty)
#=====================================================

resource "aws_iam_role" "decoy" {
  count = var.add_decoy_roles
  name  = "cg-ec2-role-${count.index + 1}-${local.resource_suffix}"
  path  = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name     = "cg-ec2-role-${count.index + 1}-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
  }
}

resource "aws_iam_role_policy" "decoy" {
  count = var.add_decoy_roles
  name  = "cg-ec2-role-${count.index + 1}-policy-${local.resource_suffix}"
  role  = aws_iam_role.decoy[count.index].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LimitedAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}
