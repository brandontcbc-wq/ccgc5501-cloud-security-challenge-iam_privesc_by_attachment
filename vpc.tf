#=====================================================
# VPC AND NETWORKING
#=====================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name     = "cg-vpc-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name     = "cg-igw-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name     = "cg-public-subnet-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name     = "cg-public-rt-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

#=====================================================
# SECURITY GROUPS
#=====================================================

resource "aws_security_group" "ec2" {
  name        = "cg-ec2-sg-${local.resource_suffix}"
  description = "Security group for CloudGoat EC2 instances"
  vpc_id      = aws_vpc.main.id

  # SSH access from whitelisted IPs
  ingress {
    description = "SSH from whitelisted IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.cg_whitelist
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "cg-ec2-sg-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
  }
}
