# Data source to fetch the official IAM policy from GitHub
data "http" "aws_load_balancer_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.3/docs/install/iam_policy.json"
}

variable "cluster_name" {}

output "aws_iam_policy_arn" {
    value = aws_iam_policy.aws_load_balancer_controller.arn
  
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy-${var.cluster_name}"
  policy      = data.http.aws_load_balancer_controller_iam_policy.response_body
}