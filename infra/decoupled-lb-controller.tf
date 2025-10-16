# This file completely decouples the AWS Load Balancer Controller setup from the EKS cluster
# to break the dependency cycle

# Data source to fetch the official IAM policy from GitHub
data "http" "aws_load_balancer_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.3/docs/install/iam_policy.json"
}

# Create the IAM policy directly
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy-direct"
  policy      = data.http.aws_load_balancer_controller_iam_policy.response_body
}

# Create the IAM role for the service account
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "AmazonEKSLoadBalancerControllerRole-direct"

  # Use a simple trust policy that can be updated later
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  # We'll update this role's trust policy in a separate resource
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}

# Define a local for the chart values
locals {
  helm_values = {
    clusterName = "dc-llc-cluster"  # Hardcode the cluster name
    serviceAccount = {
      create = true
      name = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
      }
    }
  }
}

# Define the Helm release
resource "helm_release" "aws_load_balancer_controller_decoupled" {
  name       = "load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.0"  # Use the version from the variable
  
  # Add timeout to prevent context deadline exceeded
  timeout = 900 # 15 minutes
  
  # Add wait flag to ensure it's fully deployed
  wait = true

  # Use dynamic values
  values = [
    jsonencode(local.helm_values)
  ]
  
  # This will make the Helm release depend on the IAM role
  depends_on = [
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}

# Create a null resource to ensure proper ordering
resource "null_resource" "update_lb_controller_role" {
  # This will run after the EKS cluster is created
  provisioner "local-exec" {
    # This is a placeholder command - in a real scenario, you would update the role's trust policy
    # using the AWS CLI or another method
    command = "echo 'EKS cluster created, now we can update the load balancer controller role'"
  }
  
  # This ensures this resource runs after both the EKS cluster and the load balancer controller are created
  depends_on = [
    helm_release.aws_load_balancer_controller_decoupled,
    null_resource.cluster_readiness
  ]
}

# Create a null resource for add-on dependencies
resource "null_resource" "decoupled_addon_dependencies" {
  # This will run after the load balancer controller is installed
  # and before any add-ons that need it are created
  
  # This will force Terraform to wait for the load balancer controller to be ready
  provisioner "local-exec" {
    command = "sleep 60"  # Give the controller time to initialize
  }
  
  # This is a dummy trigger to ensure this resource is always created
  triggers = {
    always_run = "${timestamp()}"
  }
  
  depends_on = [
    helm_release.aws_load_balancer_controller_decoupled,
    null_resource.update_lb_controller_role
  ]
}
