# This file ensures CoreDNS add-on is created after the AWS Load Balancer Controller is ready
# This prevents the admission webhook conflict

# Create the coredns add-on after the load balancer controller is ready
resource "aws_eks_addon" "coredns" {
  cluster_name             = module.dc-llc-cluster.cluster_name
  addon_name               = "coredns"
  addon_version            = data.aws_eks_addon_version.coredns.version
  resolve_conflicts        = "OVERWRITE"
  preserve                 = false
  most_recent              = true
  
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

# Get the latest version of coredns addon
data "aws_eks_addon_version" "coredns" {
  addon_name             = "coredns"
  kubernetes_version     = module.dc-llc-cluster.cluster_version
  most_recent            = true
}
