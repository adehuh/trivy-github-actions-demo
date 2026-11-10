# PASS example: Security Group only allows traffic from INSIDE the VPC CIDR.
# Trivy result: 0 HIGH/CRITICAL  ->  iac_security job = green
#
# NOTE: this file is only scanned statically by Trivy in CI.
# It is never applied (no `terraform apply`, no AWS credentials needed).

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
  region = "ap-southeast-3" # Jakarta
}

variable "vpc_cidr" {
  description = "Private CIDR of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "demo-shop-vpc" }
}

resource "aws_security_group" "app" {
  name        = "demo-shop-app"
  description = "App SG - internal VPC traffic only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from inside the VPC only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # GOOD: 10.0.0.0/16, not the internet
  }

  egress {
    description = "HTTPS to inside the VPC only (VPC endpoints)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # GOOD
  }
}
