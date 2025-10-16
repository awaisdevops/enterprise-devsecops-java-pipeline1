# Terraform Dependency Cycle Fix

## Problem

A circular dependency was detected in the Terraform configuration with the following errors:

```
Error: Cycle: module.lb-service-iam-role-service-account.var.oidc_issuer_url (expand), module.lb-service-iam-role-service-account.var.oidc_provider_arn (expand), module.lb-service-iam-role-service-account.var.cluster_name (expand), module.lb-service-iam-role-service-account.aws_iam_role.aws_load_balancer_controller, module.lb-service-iam-role-service-account.output.aws_iam_role_arn (expand), provider["registry.terraform.io/hashicorp/helm"], module.dc-llc-cluster.output.cluster_addons (expand), ...
```

And after the first fix:

```
Error: Cycle: provider["registry.terraform.io/hashicorp/helm"], module.lb-service-iam-role-service-account.aws_iam_role_policy_attachment.aws_load_balancer_controller, module.lb-service-iam-policy-role.var.cluster_name (expand), module.lb-service-iam-policy-role.aws_iam_policy.aws_load_balancer_controller, module.lb-service-iam-policy-role.output.aws_iam_policy_arn (expand), ...
```

The circular dependency was caused by:

1. The `helm_release.aws_load_balancer_controller` depends on `module.dc-llc-cluster`
2. The `helm_release.aws_load_balancer_controller` also depends on `module.lb-service-iam-role-service-account.aws_iam_role_arn`
3. The `module.lb-service-iam-role-service-account` depends on outputs from `module.dc-llc-cluster` (cluster_name, oidc_provider_arn, cluster_oidc_issuer_url)
4. The `module.lb-service-iam-policy-role` depends on `module.dc-llc-cluster.cluster_name`
5. The Kubernetes and Helm providers depend on `module.dc-llc-cluster` outputs
6. The `null_resource.addon_dependencies` depends on `helm_release.aws_load_balancer_controller`
7. The EKS cluster module has dependencies that eventually lead back to `null_resource.addon_dependencies`

## Solution

The solution breaks the circular dependency by completely decoupling the AWS Load Balancer Controller from the EKS cluster:

1. Creating a new file `break-dependency-cycle.tf` that:
   - Defines a local variable `cluster_outputs` to safely access EKS cluster outputs
   - Uses `try()` to handle the case when the cluster outputs aren't available yet
   - Creates a `null_resource.cluster_readiness` to ensure the cluster is created before using its outputs
   - Adds a data source for the AWS region

2. Creating a new file `decoupled-lb-controller.tf` that:
   - Defines all AWS Load Balancer Controller resources directly (IAM policy, IAM role, Helm release)
   - Uses hardcoded values where necessary to avoid referencing cluster outputs
   - Creates a separate dependency chain for the load balancer controller resources
   - Provides a null_resource to update the role's trust policy after the cluster is created

3. Modifying `main.tf` to:
   - Remove all IAM modules related to the load balancer controller
   - Use `try()` functions in the Kubernetes and Helm providers to avoid early evaluation

4. Disabling the original `aws-load-balancer-controller.tf` file:
   - Renamed to aws-load-balancer-controller.tf.disabled
   - Removed from the active Terraform configuration

5. Modifying `eks-addon-ordering.tf` to:
   - Depend on the new decoupled addon dependencies resource
   - Add a timestamp trigger to ensure the resource is always created

6. Modifying `eks-cluster.tf` to:
   - Remove the dependency on the `null_resource.addon_dependencies` resource
   - Remove the duplicate `aws_region` data source

7. Removing the `direct-lb-policy.tf` file as its functionality is now in the decoupled file

8. Fixing the KMS alias and CloudWatch Log Group references:
   - Updated the KMS key reference in eks-lifecycle.tf to use the module's output
   - Updated the import statements in import.tf to reference the local resources

## How to Apply the Fix

1. Run `terraform init` to initialize the Terraform configuration
2. Run `terraform plan` to verify that the dependency cycle is resolved
3. Run `terraform apply` to apply the changes

## Additional Notes

- The `try()` function is used to handle the case when the cluster outputs aren't available yet
- The `null_resource.cluster_readiness` ensures that the cluster is created before using its outputs
- The local variables provide a way to safely access the cluster outputs without creating a circular dependency
