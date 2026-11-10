# FAIL example (intentionally insecure): SSH open to the whole internet.
# Trivy result: CRITICAL  ->  iac_security job = red (if this were scanned by the gate)
#
# CI skips this folder in the gate and instead runs a "policy self-test" that
# EXPECTS Trivy to block it - proving the gate really works.
# Never applied (no `terraform apply`, no AWS credentials needed).

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-3"
}

resource "aws_security_group" "bastion" {
  name        = "demo-shop-bastion"
  description = "Bastion SG - INSECURE example"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # BAD: whole IPv4 internet  -> AWS-0107 HIGH
  }

  ingress {
    description      = "SSH from anywhere (IPv6)"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"] # BAD: whole IPv6 internet  -> AWS-0107 HIGH
  }

  egress {
    description = "Everything to anywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # BAD: unrestricted egress  -> AWS-0104 CRITICAL
  }
}
