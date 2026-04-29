---
name: aws-isengard-auth
description: Authenticate to AWS accounts via Isengard using ada credentials. Use when setting up AWS access, refreshing credentials, or switching accounts/regions.
---

## Credential Refresh

```bash
ada credentials update --once --account <ACCOUNT_ID> --role <ROLE> --provider conduit --profile <PROFILE>
export AWS_PROFILE=<PROFILE>
aws sts get-caller-identity
```

## Multi-Account Setup

Use named profiles in `~/.aws/config`. Refresh each separately. Always verify with `aws sts get-caller-identity` before write operations.

## Common Roles

- `Admin` — full access (use sparingly)
- `ReadOnly` — safe for exploration
- `PowerUser` — most operations without IAM changes

## Safety

- Verify which account before destructive operations
- Credentials expire — refresh before long-running tasks
- Never hardcode account IDs — use profile names
- Set `AWS_DEFAULT_REGION` explicitly
