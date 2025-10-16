//variable "repo_chart" {
  //default = "https://aws.github.io/eks-charts"
//}

variable "lb_chart" {
  default = "aws-load-balancer-controller"
}

variable "lb_namespace" {
  default = "kube-system"
}

variable "helm_version" {
  default = "1.8.0" # example — use latest version from repo if you want
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = var.lb_namespace
  version    = var.helm_version
  
  # Add timeout to prevent context deadline exceeded
  timeout = 900 # 15 minutes
  
  # Add wait flag to ensure it's fully deployed
  wait = true

  set = [
    {
      name  = "clusterName"
      value = local.cluster_outputs.cluster_name
    },
    {
      name  = "region"
      value = data.aws_region.current.region
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.lb-service-iam-role-service-account.aws_iam_role_arn
    }
  ]
  
  # Ensure this depends on the EKS cluster and IAM role being fully ready
  depends_on = [
    null_resource.cluster_readiness,
    module.lb-service-iam-role-service-account
  ]
}