terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "ap-northeast-2"
}

module "security_group" {
  source            = "./security-groups"
  ec2_sg_name       = "SG for EC2 to allow ports 22, 80 and 443"
  vpc_id            = module.dc-llc-vpc.vpc_id
  public_cidr_block = module.dc-llc-vpc.public_subnets_cidr_blocks[0]
  ec2_sg_nexus      = "Enable the port 9000 for SonarQube deployment"
}

module "ec2" {
  source = "./ec2"
  ami_id = "ami-099099dff4384719c"

  instance_type            = "t2.micro"
  tag_name                 = "dc-llc-nexus"
  public_key               = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5KB+Qcik6BNdQnH1K6UNh1GwqXjtUW/ePHUynU37a3TCT1lrEMzRHrbRpNhSCOOWhfWmkS6J2qcNaboveot98Ur47XhwppKaF9HHHFD0l+2KYeh3uwiZHSH1ikS2Ip/e7mwr2Up41HWVhGWskq/cIE8wf8Zy9XaaSLWsCYEXt4cx9g1m9Qm066taCl056gtLoyCaN7xchbkm4nJkHbpZbVplaJOUgl2agnexhwDSjb8rIwlqmT0mCDfhw3Ej3P0W2k54U+BKjggYMerpUXfCfIe3vGcJTNaUAZoYq3csKavjOC/PL9WCiYZiVEYDm8pBFefmlDjrXI0udHbGeh1UKme1MwJYDCs2Y3KYU6CT9KrcEKOIOjfnUrE50Yf/QrnPBWFOlZ3gkweZCsIRmLuIkKUAxwOXGLxizIZKQ8xOzdR7ujL9uqEbRgHILdDssqEcgyGTkl9CpMxw7Z0JzoQr0FUE/OLNRCBN4FjnsPULjf7zQfzDDZN6wQdMHfIZceV8oxMpGWCxs/xUVb0lFOf7xUBYPVkk/V0D2i1UdoNR5LlMfZTSUxsxrIZ3/zq3pK8l6mYji2C3UOpsj65/ZFS6DaOGeJF+e+1ZS21XrzyaHDEcfN+yhJHQGuDpI3FhS7S8m5g/c388/m4TFQKz95765l32sghEDUu8GMdv5ZHL2Ww== awais@devops-portfolio"
  subnet_id                = module.dc-llc-vpc.public_subnets[0]
  ec2_sg_ssh_http_https    = module.security_group.ec2_sg_ssh_http_https
  ec2_sg_nexus             = module.security_group.ec2_sg_nexus
  enable_public_ip_address = true
}

module "lb_target_group" {
  source                   = "./load-balancer-target-group"
  lb_target_group_name     = "dc-llc-lb-target-group"
  lb_target_group_port     = 9000
  lb_target_group_protocol = "HTTP"
  vpc_id                   = module.dc-llc-vpc.vpc_id
  ec2_instance_id          = module.ec2.nexus_ec2_instnace_id
}

module "alb" {
  source                          = "./load-balancer"
  lb_name                         = "dc-llc-dev-lb"
  is_external                     = false
  lb_type                         = "application"
  sg_enable_ssh_https             = [module.security_group.ec2_sg_ssh_http_https, module.security_group.ec2_sg_nexus]
  subnet_ids                      = module.dc-llc-vpc.public_subnets
  tag_name                        = "dc-llc-dev-alb"
  lb_target_group_arn             = module.lb_target_group.dev_proj_1_lb_target_group_arn
  ec2_instance_id                 = module.ec2.nexus_ec2_instnace_id
  lb_listner_port                 = 80
  lb_listner_protocol             = "HTTP"
  lb_listner_default_action       = "forward"
  lb_https_listner_port           = 443
  lb_https_listner_protocol       = "HTTPS"
  dev_proj_1_acm_arn              = module.aws_ceritification_manager.dev_proj_1_acm_arn
  lb_target_group_attachment_port = 9000
}

module "hosted_zone" {
  source          = "./hosted-zone"
  domain_name     = "devops-portfolio.site"
  aws_lb_dns_name = module.alb.aws_lb_dns_name
  aws_lb_zone_id  = module.alb.aws_lb_zone_id
}

module "aws_ceritification_manager" {
  source         = "./certificate-manager"
  domain_name    = "devops-portfolio.site"
  hosted_zone_id = module.hosted_zone.hosted_zone_id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance for Ansible."
  value       = module.ec2.ec2_public_ip
}