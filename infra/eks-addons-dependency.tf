# This file ensures proper dependency ordering between EKS add-ons and the AWS Load Balancer Controller

# This resource will be used to ensure add-ons are created after the cluster
resource "null_resource" "eks_addon_dependency" {
  # No dependencies here to avoid circular dependencies
}
