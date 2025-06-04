# Terraform configuration for Azure resources

This directory provides a Terraform setup to deploy core Azure resources used in demos.
Use the variables in `variables.tf` to customize resource names and locations. The
modules keep the configuration modular so you can reuse components easily.

Example usage:

```bash
terraform init
terraform apply -var="prefix=demo" -var="resource_group_name=demo-rg" -var="location=eastus"
```
