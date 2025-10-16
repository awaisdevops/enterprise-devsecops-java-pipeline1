# This file contains import statements for existing resources to prevent creation errors

# KMS alias import disabled since we disabled KMS key creation in the EKS module
# import {
#   to = aws_kms_alias.eks_cluster_kms_alias_override
#   id = "alias/eks/dc-llc-cluster"
# }

# Import existing CloudWatch Log Group
import {
  to = aws_cloudwatch_log_group.eks_cluster_log_group_override
  id = "/aws/eks/dc-llc-cluster/cluster"
}
