# This file creates the AWS Load Balancer Controller IAM policy directly
# to break the dependency cycle with the EKS cluster

# Data source to fetch the official IAM policy from GitHub
data "http" "aws_load_balancer_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.3/docs/install/iam_policy.json"
}

# Create the IAM policy directly without using a module
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy-direct"
  policy      = data.http.aws_load_balancer_controller_iam_policy.response_body
}

# Output the policy ARN for use by the IAM role service account module
output "aws_load_balancer_controller_policy_arn" {
  value = aws_iam_policy.aws_load_balancer_controller.arn
}
