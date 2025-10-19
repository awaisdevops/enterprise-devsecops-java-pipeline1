output "dc-llc-vpc-id" {
  description = "The ID of the dc-llc-vpc VPC."
  value       = module.dc-llc-vpc.vpc_id
}

output "one_public_cidr_block" {
  description = "The CIDR block of the first public subnet."
  value       = module.dc-llc-vpc.public_subnets_cidr_blocks
}

output "public_subnets" {
  value = module.dc-llc-vpc.public_subnets

}


data "aws_availability_zones" "azs" {}

# Define variables
#variable "cluster_name" {}
variable "vpc_name" {
  default = "dc-llc-vpc"
}
variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}
variable "private_subnet_cidr_blocks" {
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
variable "public_subnet_cidr_blocks" {
  default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

# Script the VPC creation using modddule
module "dc-llc-vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name            = var.vpc_name
  cidr            = var.vpc_cidr_block
  private_subnets = var.private_subnet_cidr_blocks
  public_subnets  = var.public_subnet_cidr_blocks
  azs             = data.aws_availability_zones.azs.names

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Associate the cluster with cloud control manager  
  tags = {
    "kubernetes.io/cluster/${var.name}" = "shared" #string interpolation
  }

  # Associate the public subnet with cloud control manager and
  # load balancer with aws load balancers controller
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/elb"            = 1
  }

  # Associate the private subnet with cloud control manager and
  # internal load balancer with aws load balancers controller
  private_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/internal-elb"   = 1
  }
}

