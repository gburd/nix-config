# AWS Builder

## Authentication — Isengard via ada

```bash
# Refresh credentials for a specific account/role
ada credentials update --once --account <ACCOUNT_ID> --role <ROLE> --provider conduit --profile <PROFILE>

# Common pattern: set AWS_PROFILE after credential refresh
export AWS_PROFILE=<PROFILE>

# Verify identity
aws sts get-caller-identity

# List available accounts (if using Isengard)
# Check https://isengard.amazon.com for account IDs and roles
```

Always verify credentials before running destructive operations. Credentials expire — refresh before long-running tasks.

## Multi-Account / Multi-Region

- Use named profiles in `~/.aws/config` for each account/role combination
- Set `AWS_DEFAULT_REGION` or pass `--region` explicitly — never assume a region
- Tag all resources: `Owner=gregburd`, `Purpose=<description>`, `Expiry=<date>`
- Use `aws sts get-caller-identity` to confirm which account you're operating in before any write operation

## Git Conventions

- Use `-P` flag on git commands that produce paginated output
- Commit messages follow Conventional Commits: `type(scope): description`
- Never force push, never rewrite history, never push to main directly
- Always build and test before committing

## AWS CLI Patterns

```bash
# Always use --output json for scripting, --output table for human reading
aws ec2 describe-instances --output table
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[]'

# Dry-run before destructive operations
aws ec2 run-instances --dry-run ...

# Use --query for server-side filtering
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,Tags]'
```

## Cost Awareness

- Prefer spot instances for testing workloads
- Set auto-terminate timers or expiry tags on test resources
- Check `aws ce get-cost-and-usage` periodically
- Shut down resources when done — don't leave instances running overnight
