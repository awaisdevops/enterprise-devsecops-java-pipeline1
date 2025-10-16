# Terraform Dependency Cycle Fix

## Problem

A circular dependency was detected in the Terraform configuration with the following error:

```
Error: Cycle: module.lb-service-iam-role-service-account.var.oidc_issuer_url (expand), module.lb-service-iam-role-service-account.var.oidc_provider_arn (expand), module.lb-service-iam-role-service-account.var.cluster_name (expand), module.lb-service-iam-role-service-account.aws_iam_role.aws_load_balancer_controller, module.lb-service-iam-role-service-account.output.aws_iam_role_arn (expand), provider["registry.terraform.io/hashicorp/helm"], module.dc-llc-cluster.output.cluster_addons (expand), ...
```

The circular dependency was caused by:

1. The `helm_release.aws_load_balancer_controller` depends on `module.dc-llc-cluster`
2. The `helm_release.aws_load_balancer_controller` also depends on `module.lb-service-iam-role-service-account.aws_iam_role_arn`
3. The `module.lb-service-iam-role-service-account` depends on outputs from `module.dc-llc-cluster` (cluster_name, oidc_provider_arn, cluster_oidc_issuer_url)
4. The `null_resource.addon_dependencies` depends on `helm_release.aws_load_balancer_controller`
5. The EKS cluster module has dependencies that eventually lead back to `null_resource.addon_dependencies`

## Solution

The solution breaks the circular dependency by:

1. Creating a new file `break-dependency-cycle.tf` that:
   - Defines a local variable `cluster_outputs` to safely access EKS cluster outputs
   - Uses `try()` to handle the case when the cluster outputs aren't available yet
   - Creates a `null_resource.cluster_readiness` to ensure the cluster is created before using its outputs

2. Modifying `main.tf` to:
   - Use the local variables instead of direct module outputs
   - Add a dependency on `null_resource.cluster_readiness`

3. Modifying `aws-load-balancer-controller.tf` to:
   - Use the local variables instead of direct module outputs
   - Depend on both `null_resource.cluster_readiness` and `module.lb-service-iam-role-service-account`

4. Simplifying `eks-addon-ordering.tf` by:
   - Removing the local variable that directly referenced a module output

## How to Apply the Fix

1. Run `terraform init` to initialize the Terraform configuration
2. Run `terraform plan` to verify that the dependency cycle is resolved
3. Run `terraform apply` to apply the changes

## Additional Notes

- The `try()` function is used to handle the case when the cluster outputs aren't available yet
- The `null_resource.cluster_readiness` ensures that the cluster is created before using its outputs
- The local variables provide a way to safely access the cluster outputs without creating a circular dependency
