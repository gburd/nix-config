# Amazon Bedrock Setup for Claude Code

## Overview

This configuration uses Amazon Bedrock as the LLM provider for Claude Code instead of the Anthropic API.

## Prerequisites

1. AWS account with Bedrock access enabled
2. Bedrock model access granted (specifically for Claude models)
3. AWS credentials (Access Key ID and Secret Access Key)

## Setup Instructions

### 1. Add AWS Credentials to Secrets

You need to add your AWS credentials to the sops-encrypted secrets file. The credentials should be stored at the path `aws/credentials` in the secrets structure.

#### For floki (or your specific host):

```bash
# Edit the secrets file (will decrypt, open editor, re-encrypt on save)
cd ~/ws/nix-config
sops nixos/workstation/floki/secrets.yaml
```

Add the following structure to your secrets file:

```yaml
aws:
  credentials: |
    [default]
    aws_access_key_id = YOUR_ACCESS_KEY_ID
    aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
    region = us-east-1
```

Replace `YOUR_ACCESS_KEY_ID` and `YOUR_SECRET_ACCESS_KEY` with your actual AWS credentials.

### 2. Configure the Secret in NixOS

The secret needs to be declared in your NixOS configuration. Add to your host configuration (e.g., `nixos/workstation/floki/default.nix`):

```nix
sops.secrets."aws/credentials" = {
  mode = "0600";
  owner = config.users.users.gburd.name;
  path = "/home/gburd/.aws/credentials";
};
```

Or in your home-manager configuration:

```nix
sops.secrets."aws/credentials" = {
  mode = "0600";
  path = "${config.home.homeDirectory}/.aws/credentials";
};
```

### 3. Verify Configuration

After rebuilding your system/home-manager configuration:

```bash
# Check that credentials file exists and has correct permissions
ls -la ~/.aws/credentials

# Test AWS access
aws bedrock list-foundation-models --region us-east-1

# Verify Claude Code can access Bedrock
claude --version
```

## Configuration Files

The AI configuration is located in:
- `home-manager/_mixins/users/gburd/ai-config.nix` - Main AI configuration
- `modules/home-manager/ai/bedrock.nix` - Bedrock module
- `modules/home-manager/ai/mcps.nix` - MCP servers configuration

## MCP Servers Configured

1. **GitHub MCP Server** - Interact with GitHub repositories, PRs, and issues
   - Requires: `gh auth login` to be run first

2. **memelord** - Persistent memory for coding agents
   - Stores project-specific knowledge across sessions

3. **llms.txt Documentation** - Access to NixOS and Home Manager docs
   - Provides context-aware documentation

## Troubleshooting

### AWS Credentials Not Found

```bash
# Check if secret is properly decrypted
cat ~/.aws/credentials

# Verify sops can decrypt
sops -d nixos/workstation/floki/secrets.yaml
```

### Bedrock Access Denied

1. Verify your AWS account has Bedrock enabled in your region
2. Request model access in AWS Console: Bedrock → Model access
3. Ensure your IAM user/role has `bedrock:InvokeModel` permission

### MCP Servers Not Loading

```bash
# Check MCP configuration
cat ~/.config/claude-code/mcp.json

# Verify github auth
gh auth status

# Test memelord
memelord --help
```

## AWS IAM Policy

Your AWS user/role needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:*::foundation-model/anthropic.claude-*"
    }
  ]
}
```
