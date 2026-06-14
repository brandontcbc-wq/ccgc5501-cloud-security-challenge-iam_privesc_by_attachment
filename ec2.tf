#=====================================================
# EC2 - TARGET SERVER
# This is the "super-critical-security-server" that 
# the attacker needs to terminate to complete the scenario
#=====================================================

resource "aws_instance" "target" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.meek.name

  # User data script for basic setup
  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y awscli
    echo "Super Critical Security Server" > /var/www/html/index.html
    echo "CloudGoat Scenario: ${var.scenario_name}" >> /var/www/html/index.html
    echo "CGID: ${var.cgid}" >> /var/www/html/index.html
  EOF

  tags = {
    Name     = "cg-${var.target_server_name}-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
    Purpose  = "Target for privilege escalation scenario"
  }

  # Prevent accidental destruction during testing
  # Remove this if you want the scenario to be completable via Terraform
  # lifecycle {
  #   prevent_destroy = true
  # }
}

#=====================================================
# SSH KEY PAIR (Optional - for debugging)
# Uncomment if you want SSH access to the target server
#=====================================================

# resource "tls_private_key" "cloudgoat" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }
# 
# resource "aws_key_pair" "cloudgoat" {
#   key_name   = "cg-keypair-${local.resource_suffix}"
#   public_key = tls_private_key.cloudgoat.public_key_openssh
# 
#   tags = {
#     Name     = "cg-keypair-${local.resource_suffix}"
#     Scenario = var.scenario_name
#     Stack    = "CloudGoat"
#   }
# }
# 
# resource "local_file" "private_key" {
#   content         = tls_private_key.cloudgoat.private_key_pem
#   filename        = "${path.module}/cloudgoat.pem"
#   file_permission = "0400"
# }
