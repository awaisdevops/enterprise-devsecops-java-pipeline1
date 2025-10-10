variable "cluster_name" {}
variable "oidc_provider_arn" {}
variable "aws_iam_policy_arn" {}
variable "oidc_issuer_url" {}

output "aws_iam_role_arn" {
    value = aws_iam_role.aws_load_balancer_controller.arn
  
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "AmazonEKSLoadBalancerControllerRole-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {

        "Effect": "Allow",
        "Principal": {

          "Federated": "${var.oidc_provider_arn}"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {          
          "StringEquals": {
            # The key must be the OIDC issuer URL (without "https://") + :sub
            "${replace(var.oidc_issuer_url, "https://", "")}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
            # Add a condition for the audience (aud) to prevent unauthorized token use
            "${replace(var.oidc_issuer_url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = var.aws_iam_policy_arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}