# This file ensures that the add-ons are created in the correct order

# Create a local variable for the EKS cluster name
locals {
  eks_cluster_name = module.dc-llc-cluster.cluster_name
}

# Create explicit dependencies between the add-ons and the load balancer controller
resource "null_resource" "addon_dependencies" {
  # This will run after the load balancer controller is installed
  # and before any add-ons that need it are created
  
  # Ensure this runs after the load balancer controller is installed
  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
  
  # This will force Terraform to wait for the load balancer controller to be ready
  # before creating any add-ons that depend on it
  provisioner "local-exec" {
    command = "sleep 60"  # Give the controller time to initialize
  }
}
