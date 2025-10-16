# This file preserves existing AWS Load Balancer Controller resources to prevent them from being destroyed

# Preserve the existing IAM role for the AWS Load Balancer Controller
resource "aws_iam_role" "preserve_lb_controller_role" {
  name = "AmazonEKSLoadBalancerControllerRole-dc-llc-cluster"
  
  # Use a simple assume role policy that can be updated later
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
  
  # Prevent this resource from being destroyed
  lifecycle {
    ignore_changes = [assume_role_policy]
    prevent_destroy = true
  }
}

# Preserve the existing IAM policy attachment
resource "aws_iam_role_policy_attachment" "preserve_lb_controller_attachment" {
  role       = aws_iam_role.preserve_lb_controller_role.name
  policy_arn = "arn:aws:iam::195275648938:policy/AWSLoadBalancerControllerIAMPolicy-dc-llc-cluster"
  
  # Prevent this resource from being destroyed
  lifecycle {
    prevent_destroy = true
  }
}

# Import statements for existing resources
import {
  to = aws_iam_role.preserve_lb_controller_role
  id = "AmazonEKSLoadBalancerControllerRole-dc-llc-cluster"
}

import {
  to = aws_iam_role_policy_attachment.preserve_lb_controller_attachment
  id = "AmazonEKSLoadBalancerControllerRole-dc-llc-cluster/arn:aws:iam::195275648938:policy/AWSLoadBalancerControllerIAMPolicy-dc-llc-cluster"
}
