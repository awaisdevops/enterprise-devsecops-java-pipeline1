# This file contains import statements for existing resources to prevent creation errors

# Import existing KMS alias
import {
  to = module.dc-llc-cluster.module.kms.aws_kms_alias.this["cluster"]
  id = "alias/eks/dc-llc-cluster"
}

# Import existing CloudWatch Log Group
import {
  to = module.dc-llc-cluster.aws_cloudwatch_log_group.this[0]
  id = "/aws/eks/dc-llc-cluster/cluster"
}
