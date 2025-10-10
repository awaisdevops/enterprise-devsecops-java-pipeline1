variable "name" {
  default = "dc-llc-cluster"
}
variable "k8s_version" {
  default = "1.33"
}

output "cluster_endpoint" {
  value = module.dc-llc-cluster.cluster_endpoint  
  #value = module.dc-llc-cluster.cluster.endpoint
  
}

data "aws_region" "current" {}

output "cluster_certificate_authority_data" {
  value = module.dc-llc-cluster.cluster_certificate_authority_data
  #value = module.dc-llc-cluster.cluster.certificate_authority_data 
}

output "cluster_name" {
  value = module.dc-llc-cluster.cluster_name
  #value = module.dc-llc-cluster.cluster.name 
}

#The full OIDC Provider ARN (used to reference the IAM Identity Provider)
output "oidc_provider_arn" {
  value = module.dc-llc-cluster.oidc_provider_arn
  #value = module.dc-llc-cluster.cluster.oidc_provider_arn
}

# The OIDC Issuer URL (the raw URL string)
output "cluster_oidc_issuer_url" {
  #value = module.dc-llc-cluster.oidc_issuer_url
  value = module.dc-llc-cluster.cluster_oidc_issuer_url
}

module "dc-llc-cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.1.3"

  name    = var.name
  kubernetes_version = var.k8s_version
  endpoint_public_access  = true

  /*
  # Including the add-on as part of EKS module
  cluster_addons = {    
    aws-ebs-csi-driver = {}
  }
  */
  
  addons = {
    coredns              = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy             = {}
    vpc-cni              = {
      before_compute = true
    }
    #aws-ebs-csi-driver = {} 
  }
  

  # Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  # Refering through modules's outputs 
  vpc_id     = module.dc-llc-vpc.vpc_id
  subnet_ids = module.dc-llc-vpc.private_subnets

  # EKS Managed Node Group
  eks_managed_node_groups = {
    dc-llc-ng = {
      name           = "node-group-1"
      instance_types = ["t2.small"]
      ami_type       = "AL2023_x86_64_STANDARD"
      min_size       = 1
      max_size       = 1
      desired_size   = 1
    }
  }

  # Adding associated permissions as part of node group configuration
  iam_role_additional_policies = {
    AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  tags = {
    environment = "dev"
    application = "dc-llc-app"
  }

}
