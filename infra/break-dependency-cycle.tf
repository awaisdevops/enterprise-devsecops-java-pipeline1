# This file breaks the circular dependency between the EKS cluster, IAM roles, and Helm charts

# Get current AWS region
data "aws_region" "current" {}

# Create a local variable to hold the cluster outputs we need
locals {
  # These will be used for IAM role creation without creating circular dependencies
  cluster_outputs = {
    cluster_name           = try(module.dc-llc-cluster.cluster_name, "")
    oidc_provider_arn      = try(module.dc-llc-cluster.oidc_provider_arn, "")
    oidc_issuer_url        = try(module.dc-llc-cluster.cluster_oidc_issuer_url, "")
  }
}

# Create a null resource to ensure the cluster is created before we try to use its outputs
resource "null_resource" "cluster_readiness" {
  depends_on = [
    module.dc-llc-cluster
  ]
}
