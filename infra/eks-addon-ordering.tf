# This file ensures that the add-ons are created in the correct order

# Create explicit dependencies between the add-ons and the load balancer controller
resource "null_resource" "addon_dependencies" {
  # This will run after the load balancer controller is installed
  # and before any add-ons that need it are created
  
  # Ensure this runs after the decoupled load balancer controller is installed
  depends_on = [
    null_resource.decoupled_addon_dependencies
  ]
  
  # This will force Terraform to wait for the load balancer controller to be ready
  # before creating any add-ons that depend on it
  provisioner "local-exec" {
    command = "sleep 10"  # Reduced sleep time since we already waited in decoupled_addon_dependencies
  }
  
  # This is a dummy trigger to ensure this resource is always created after the cluster
  # but doesn't create a circular dependency
  triggers = {
    always_run = "${timestamp()}"
  }
}
