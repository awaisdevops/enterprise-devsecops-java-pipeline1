variable "ec2_sg_name" {}
variable "vpc_id" {}
variable "ec2_sg_nexus" {}
#variable "public_subnet_cidr_block" {}
variable "public_cidr_block" {}

output "ec2_sg_ssh_http_https" {
  value = aws_security_group.ec2_sg_ssh_http_https.id
}

output "ec2_sg_nexus" {
  value =  aws_security_group.ec2_sg_nexus.id
}

resource "aws_security_group" "ec2_sg_ssh_http_https" {
  name        = var.ec2_sg_name
  description = "Enable the ports 22 & 80 for ssh and http"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow remote SSH from anywhere"
    cidr_blocks = ["0.0.0.0/0"]
    #cidr_blocks = [var.public_cidr_block] 
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  ingress {
    description = "Allow HTTP request from anywhere"
    cidr_blocks = ["0.0.0.0/0"]
    #cidr_blocks = [var.public_cidr_block]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  ingress {
    description = "Allow HTTP request from anywhere"
    cidr_blocks = ["0.0.0.0/0"]
    #cidr_blocks = [var.public_cidr_block]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }

  egress {
    description = "Allow outgoing request"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allowing the port numbers 22, 80 and 443."
  }
}

resource "aws_security_group" "ec2_sg_nexus" {
  name        = var.ec2_sg_nexus
  description = "Enable the port 8081 for Nexus deployment"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow the inbound traffic on port 9000"
    cidr_blocks = ["0.0.0.0/0"]
    #cidr_blocks = [var.public_cidr_block]
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
  }

  egress {
    description = "Allow outgoing request"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG to allow incoming requests for Nexus on port 8081 and 8082"
  }
}