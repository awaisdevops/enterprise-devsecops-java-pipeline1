variable "ami_id" {}
variable "instance_type" {}
variable "tag_name" {}
variable "public_key" {}
variable "subnet_id" {}
variable "ec2_sg_ssh_http_https" {}
variable "enable_public_ip_address" {}
variable "ec2_sg_nexus" {}

output "ec2_public_ip" {
  description = "Public IP address of the Nexus EC2 instance"
  value       = aws_instance.dc-llc-nexus.public_ip
}

output "nexus_ec2_instnace_id" {
  value = aws_instance.dc-llc-nexus.id
  
}


resource "aws_instance" "dc-llc-nexus" {
  ami           = var.ami_id
  instance_type = var.instance_type
  tags = {
    Name = var.tag_name
  }
  key_name                    = "nexus_security_key"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.ec2_sg_ssh_http_https, var.ec2_sg_nexus]
  associate_public_ip_address = var.enable_public_ip_address

  metadata_options {
    http_endpoint = "enabled"  
    http_tokens   = "required" 
  }
}

resource "aws_key_pair" "nexus-public_key" {
  key_name   = "nexus_security_key"
  public_key = var.public_key
}