# Using tea CLI with Codeberg

`tea` is the official CLI for Gitea/Forgejo instances, including Codeberg.org. It provides similar functionality to GitHub CLI (`gh`) but works with Gitea-based Git forges.

## What is Codeberg?

[Codeberg.org](https://codeberg.org) is a non-profit, community-led Git hosting platform running on Forgejo (a Gitea fork). It's a privacy-focused, ad-free alternative to GitHub.

## Installation

`tea` is included in your configuration via `home-manager/_mixins/cli/tea.nix`.

After rebuilding:
```bash
home-manager switch --flake .#gburd@floki
tea --version
```

## Initial Setup

### 1. Login to Codeberg

```bash
# Login to Codeberg
tea login add

# You'll be prompted for:
# - URL: https://codeberg.org
# - Name: codeberg (or any name you want)
# - Authentication method: Token or SSH

# For token auth:
# 1. Go to https://codeberg.org/user/settings/applications
# 2. Generate a new token with repo permissions
# 3. Paste it when prompted
```

### 2. Set Default Login

```bash
# List configured logins
tea login list

# Set Codeberg as default
tea login default codeberg
```

### 3. Verify Setup

```bash
# Check current login
tea login

# Test by listing your repos
tea repos ls
```

## Common Commands

### Repository Operations

```bash
# Clone a repository
tea repo clone owner/repo

# List your repositories
tea repos ls

# Create a new repository
tea repo create my-new-repo --description "My project"

# Fork a repository
tea repo fork owner/repo

# View repository info
tea repo owner/repo
```

### Issues

```bash
# List issues
tea issues ls

# List issues for specific repo
tea issues ls --repo owner/repo

# Create an issue
tea issues create --title "Bug report" --body "Description"

# View an issue
tea issues 123

# Close an issue
tea issues close 123

# Comment on an issue
tea comment 123 "This is fixed now"
```

### Pull Requests

```bash
# List pull requests
tea pulls ls

# Create a pull request
tea pulls create \
  --title "Add feature" \
  --body "This PR adds..." \
  --head my-branch \
  --base main

# View a pull request
tea pulls 42

# Checkout a pull request locally
tea pulls checkout 42

# Review a pull request
tea pulls approve 42
tea pulls reject 42

# Merge a pull request
tea pulls merge 42

# List PR reviews
tea pulls reviews 42
```

### Releases

```bash
# List releases
tea releases ls

# Create a release
tea releases create v1.0.0 \
  --title "Version 1.0.0" \
  --note "Release notes here" \
  --asset build/binary

# Download release assets
tea releases download v1.0.0
```

### Labels & Milestones

```bash
# List labels
tea labels ls

# Create a label
tea labels create bug --color ff0000 --description "Bug reports"

# List milestones
tea milestones ls

# Create a milestone
tea milestones create "v1.0" --description "First stable release"

# Add issue to milestone
tea issues 123 --milestone "v1.0"
```

## Working with Multiple Forges

You can configure `tea` to work with multiple Gitea/Forgejo instances:

```bash
# Add multiple logins
tea login add  # Codeberg
tea login add  # Your self-hosted Gitea

# Switch between them
tea login use codeberg
tea login use my-gitea

# Or specify login per command
tea --login codeberg repos ls
tea --login my-gitea repos ls
```

## Configuration

`tea` stores its config in `~/.config/tea/config.yml`:

```yaml
logins:
- name: codeberg
  url: https://codeberg.org
  token: your-token-here
  default: true
  sshhost: codeberg.org
  user: yourusername
```

You can also set preferences:

```bash
# Set editor for commit messages, PR descriptions, etc.
tea config editor nvim

# Set default remote
tea config remote origin

# Show current config
tea config
```

## SSH Key Management

If you use SSH authentication:

```bash
# List SSH keys on Codeberg
tea login ssh-keys

# Add your SSH key
tea login ssh-keys add ~/.ssh/id_ed25519.pub

# Remove an SSH key
tea login ssh-keys rm <key-id>
```

## Useful Workflows

### Quick Issue Creation from Command Line

```bash
#!/usr/bin/env bash
# Create issue with template
tea issues create \
  --title "$(echo "$1")" \
  --body "$(cat <<EOF
## Description
$2

## Steps to Reproduce
1.
2.
3.

## Expected Behavior


## Actual Behavior

EOF
)"
```

### Clone All Your Repos

```bash
# Clone all your repos to a directory
mkdir -p ~/codeberg
cd ~/codeberg
tea repos ls --output simple | while read repo; do
  tea repo clone "$repo"
done
```

### Bulk Label Management

```bash
# Add labels to multiple issues
for issue in 1 2 3 4 5; do
  tea issues label $issue --add bug --add priority:high
done
```

## Comparison: tea vs gh

| Feature | `gh` (GitHub) | `tea` (Codeberg/Gitea) |
|---------|---------------|------------------------|
| Forge Support | GitHub only | Any Gitea/Forgejo |
| Issues | ✅ | ✅ |
| Pull Requests | ✅ | ✅ |
| Releases | ✅ | ✅ |
| Actions/CI | ✅ | ❌ (Forgejo uses Woodpecker) |
| Discussions | ✅ | ❌ |
| Codespaces | ✅ | ❌ |
| Multi-instance | ❌ | ✅ |

## Troubleshooting

### Authentication Failed

```bash
# Remove old login and re-add
tea login rm codeberg
tea login add
```

### SSH Connection Issues

```bash
# Test SSH connection to Codeberg
ssh -T git@codeberg.org

# If it fails, check your SSH config
cat ~/.ssh/config
```

### Token Permissions

If operations fail, ensure your token has the right permissions:
- `read:user` - Read user info
- `repo` - Full repository access
- `write:repository` - Modify repositories
- `write:issue` - Create/modify issues

Generate a new token at: https://codeberg.org/user/settings/applications

### Can't Find Repository

```bash
# Specify full repo path
tea issues ls --repo owner/repo

# Or set default repo in git directory
cd /path/to/repo
tea issues ls  # Uses current repo
```

## Tips & Tricks

**1. Set up shell aliases:**
```bash
# In ~/.config/fish/config.fish
alias tpr='tea pulls'
alias ti='tea issues'
alias tr='tea repos'
```

**2. Use with git:**
```bash
# tea works in git repositories
cd my-codeberg-project
tea issues create  # Automatically knows the repo
```

**3. JSON output for scripting:**
```bash
# Get machine-readable output
tea issues ls --output json | jq '.[] | select(.state == "open")'
```

**4. Create from template:**
```bash
# Use issue templates
tea issues create --template bug_report.md
```

## Resources

- [tea Documentation](https://gitea.com/gitea/tea)
- [Codeberg Documentation](https://docs.codeberg.org/)
- [Forgejo Documentation](https://forgejo.org/docs/)
- Tea GitHub: https://github.com/go-gitea/tea

## See Also

- GitHub CLI setup: `docs/GITHUB_CLI.md` (if you create one)
- Git configuration: `home-manager/_mixins/cli/git.nix`
- SSH setup: `home-manager/_mixins/cli/ssh.nix`
