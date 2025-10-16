# This file contains import statements for existing resources to prevent creation errors

# Import existing KMS alias
import {
  to = aws_kms_alias.eks_cluster_kms_alias_override[0]
  id = "alias/eks/dc-llc-cluster"
}

# Import existing CloudWatch Log Group
import {
  to = aws_cloudwatch_log_group.eks_cluster_log_group_override[0]
  id = "/aws/eks/dc-llc-cluster/cluster"
}
