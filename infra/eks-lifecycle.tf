# This file adds lifecycle rules to prevent recreation of existing resources

# KMS alias is disabled since we disabled KMS key creation in the EKS module
# resource "aws_kms_alias" "eks_cluster_kms_alias_override" {
#   name          = "alias/eks/dc-llc-cluster"
#   target_key_id = module.dc-llc-cluster.kms_key_id
#   
#   lifecycle {
#     ignore_changes = [name, target_key_id]
#     # Prevent this resource from being created or destroyed
#     prevent_destroy = true
#   }
# }

# Add lifecycle rules to prevent recreation of CloudWatch Log Group
resource "aws_cloudwatch_log_group" "eks_cluster_log_group_override" {
  name              = "/aws/eks/dc-llc-cluster/cluster"
  retention_in_days = 90
  
  lifecycle {
    ignore_changes = [name]
  }
}
