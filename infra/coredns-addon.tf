# This file ensures CoreDNS add-on is created after the AWS Load Balancer Controller is ready
# This prevents the admission webhook conflict

# Create the coredns add-on after the load balancer controller is ready
resource "aws_eks_addon" "coredns" {
  cluster_name      = "dc-llc-cluster"
  addon_name        = "coredns"
  preserve          = false
  
  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
  
  # This ensures coredns is created after the load balancer controller is ready
  depends_on = [
    null_resource.decoupled_addon_dependencies
  ]
}
