# AWS Terraform

Terraform workflow with Isengard credentials. Covers init, plan, apply, state management, and NixOps integration.

## Workflow

```bash
# Always plan before apply
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Destroy (with confirmation)
terraform plan -destroy -out=tfplan-destroy
terraform apply tfplan-destroy
```

## State Backend (S3 + DynamoDB)

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "project/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## Isengard Integration

```bash
# Refresh credentials before terraform operations
ada credentials update --once --account <ACCOUNT_ID> --role <ROLE> --provider conduit --profile <PROFILE>
export AWS_PROFILE=<PROFILE>

# Verify before apply
aws sts get-caller-identity
terraform plan -out=tfplan
```

## Module Patterns

```hcl
module "vpc" {
  source = "./modules/vpc"
  cidr   = "10.0.0.0/16"
  tags   = { Owner = "gregburd", Purpose = "testing", Expiry = "2026-05-01" }
}
```

## NixOps Integration

NixOps manages machine configurations; Terraform manages AWS infrastructure. Use Terraform for VPCs, security groups, IAM roles. Use NixOps for instance provisioning and configuration.

## Safety

- Always `terraform plan` before `terraform apply`
- Never apply without reviewing the plan
- Tag all resources: Owner, Purpose, Expiry
- Use workspaces for environment separation: `terraform workspace select dev`
- Lock state with DynamoDB to prevent concurrent modifications
- Confirm account before apply: `aws sts get-caller-identity`
