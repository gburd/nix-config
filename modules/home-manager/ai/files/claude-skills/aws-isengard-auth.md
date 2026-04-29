# AWS Isengard Authentication

Authenticate to AWS accounts via Isengard using `ada credentials`. Use when setting up AWS access, refreshing credentials, or switching accounts/regions.

## Credential Refresh

```bash
# Standard pattern: refresh credentials for an account/role
ada credentials update --once --account <ACCOUNT_ID> --role <ROLE> --provider conduit --profile <PROFILE>

# Set active profile
export AWS_PROFILE=<PROFILE>

# Verify identity
aws sts get-caller-identity
```

## Multi-Account Setup

```bash
# ~/.aws/config example for multiple accounts
[profile dev]
region = us-west-2

[profile staging]
region = us-west-2

[profile prod]
region = us-east-1
```

Refresh each profile separately. Always verify with `aws sts get-caller-identity` before write operations.

## Common Roles

- `Admin` — full access (use sparingly)
- `ReadOnly` — safe for exploration
- `PowerUser` — most operations without IAM changes
- `ClineBedrockAccess` — Bedrock API access

## Safety

- Always verify which account you're in before destructive operations
- Credentials expire — refresh before long-running tasks
- Never hardcode account IDs in scripts — use profile names
- Set `AWS_DEFAULT_REGION` explicitly — never assume
