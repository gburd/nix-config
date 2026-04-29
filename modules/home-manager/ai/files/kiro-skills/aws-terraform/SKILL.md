---
name: aws-terraform
description: Terraform workflow with Isengard credentials. Covers init/plan/apply, S3+DynamoDB state backend, modules, and NixOps integration.
---

## Workflow

```bash
ada credentials update --once --account <ACCOUNT_ID> --role <ROLE> --provider conduit --profile <PROFILE>
export AWS_PROFILE=<PROFILE>
aws sts get-caller-identity

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## State Backend

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "project/terraform.tfstate"
    region = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt = true
  }
}
```

## NixOps Integration

Terraform manages AWS infrastructure (VPCs, SGs, IAM). NixOps manages instance provisioning and configuration. Keep them separate — Terraform for infra, NixOps for machines.

## Safety

- Always `plan` before `apply`
- Never apply without reviewing the plan
- Tag all resources: Owner, Purpose, Expiry
- Use workspaces for environments: `terraform workspace select dev`
- Confirm account before apply
