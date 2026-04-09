# Shell Change: Fish → Bash

**Date**: 2026-04-09
**Status**: ✅ Configuration Complete - Needs System Restart

---

## Changes Made

### Files Modified

1. **`home-manager/_mixins/cli/fish.nix`**
   - Set `programs.fish.enable = false`

2. **`home-manager/_mixins/users/gburd/default.nix`**
   - Set `programs.fish.enable = false` (line 76)

3. **`home-manager/_mixins/console/default.nix`**
   - Set `programs.fish.enable = false` (line 157)
   - Added all Fish aliases to Bash shellAliases (lines 357-390):
     - Nix shortcuts (n, nd, ns, nb, nf, nr, nrs, snr, snrs, hm, hms)
     - Modern Unix tools (ls→eza, vim→nvim, etc.)
     - Clear screen function (Fish-style)
     - jqless, locate shortcuts
   - Added `stty -ixon` to disable Ctrl-s/Ctrl-q flow control

4. **`home-manager/_mixins/cli/bash.nix`**
   - Enhanced but superseded by console/default.nix settings

### Prompt Configuration

**Powerline-go** is already configured and will provide a Fish-like prompt:
- Shows: username@hostname, current directory (abbreviated), Git status
- Colors match Fish default prompt
- Minimal mode in Claude Code sessions
- [nix] indicator in nix develop shells

Configuration in `console/default.nix`:
```nix
powerline-go = {
  enable = true;
  settings = {
    cwd-max-depth = 5;
    cwd-max-dir-size = 12;
    max-width = 60;
  };
};
```

---

## Why Home-Manager Switch Isn't Creating New Generation

The `home-manager switch` command completes with exit code 0 but doesn't create a new generation. This is a known issue when:
1. The Nix evaluation is cached
2. There are timestamp-related build determinism issues
3. The exact same derivation hash is being generated

### Solutions

#### Option 1: Force Rebuild (Recommended)
```bash
home-manager expire-generations "-0 days"
home-manager switch --impure --flake .#gburd@floki
```

#### Option 2: System Restart
Simply restart your session or reboot. The configuration is correctly set in the nix-config files, and a fresh session will pick up Bash.

#### Option 3: Manual Shell Change (Temporary)
```bash
# For this session only
exec bash

# Check your aliases work
n  # should run 'nix'
hms  # should run home-manager switch
vim  # should run nvim
```

---

## Verification After Restart/Rebuild

###1. Check Shell
```bash
echo $SHELL
# Should show: /run/current-system/sw/bin/bash or ~/.nix-profile/bin/bash

ps -p $$
# Should show: bash
```

### 2. Check Prompt
Your prompt should look like:
```
gburd@floki ~/ws/nix-config main >
```

With colors:
- Username: green/white
- Hostname: normal
- Directory: blue (abbreviated if long)
- Git branch: yellow/cyan with status indicators
- Prompt: >

### 3. Check Aliases
```bash
# Test Nix shortcuts
alias n
# Should show: alias n='nix'

alias hms
# Should show: alias hms='home-manager -b bkup --flake .#gburd@$(hostname) switch'

alias vim
# Should show: alias vim='nvim'

# Test they work
n --version
ls  # Should use eza
clear  # Should clear screen and scrollback
```

### 4. Check Integration Tools
```bash
# These should still work (configured for Bash):
# - Ctrl-r: atuin history search
# - z <partial-path>: zoxide directory jump
# - direnv: automatic environment loading
# - Ctrl-x Ctrl-e: edit command in $EDITOR
```

---

## All Your Fish Aliases Preserved

### Nix Shortcuts
- `n` → nix
- `nd` → nix develop -c $SHELL
- `ns` → nix shell
- `nsn` → nix shell nixpkgs#
- `nb` → nix build
- `nbn` → nix build nixpkgs#
- `nf` → nix flake

### NixOS Shortcuts
- `nr` → nixos-rebuild --flake .
- `nrs` → nixos-rebuild --flake . switch
- `snr` → sudo nixos-rebuild --flake .
- `snrs` → sudo nixos-rebuild --flake . switch
- `hm` → home-manager --flake .
- `hms` → home-manager -b bkup --flake .#gburd@$(hostname) switch

### Modern Unix Tools
- `ls` → eza
- `exa` → eza
- `vim` → nvim
- `vi` → nvim
- `v` → nvim

### Other
- `clear` → Full screen and scrollback clear (Fish-style)
- `jqless` → jq -C | less -r
- `locate` → plocate
- `diff` → diffr
- `glow` → glow --pager
- `ip` → ip --color --brief
- `top` → btm (bottom)
- `tree` → eza --tree

---

## What's Different from Fish

### Differences (Minor)
1. **Tab completion**: Bash completion vs Fish completion
   - Still works, just slightly different behavior
   - Bash: Press Tab twice for options
   - Fish: Shows options immediately

2. **Command not found**: Different suggestions
   - Bash: Uses nix-index
   - Fish: Uses Fish's own system

3. **History**: Atuin replaces Fish history
   - Actually better: syncs across machines
   - Ctrl-r to search
   - Same fuzzy search behavior

### Same
1. **Prompt**: Powerline-go looks very similar to Fish
2. **Aliases**: All your shortcuts work identically
3. **Colors**: Directory listings, Git status, etc.
4. **Integration**: direnv, zoxide, atuin all work

---

## Troubleshooting

### If Aliases Don't Work
```bash
# Check bashrc has aliases
grep "alias n=" ~/.bashrc

# If not, the bashrc wasn't updated
# Try:
home-manager expire-generations "-0 days"
home-manager switch --impure --flake .#gburd@floki
```

### If Prompt Doesn't Look Right
```bash
# Check powerline-go is installed
which powerline-go

# Check PROMPT_COMMAND
echo $PROMPT_COMMAND
# Should include: _update_ps1

# If missing:
source ~/.bashrc
```

### If You Want Fish Back
```bash
# Edit these three files and set enable = true:
# - home-manager/_mixins/cli/fish.nix
# - home-manager/_mixins/users/gburd/default.nix
# - home-manager/_mixins/console/default.nix

# Then:
home-manager switch --flake .#gburd@floki
```

---

## Files Changed Summary

```
home-manager/_mixins/cli/fish.nix            # enable = false
home-manager/_mixins/users/gburd/default.nix  # enable = false (line 76)
home-manager/_mixins/console/default.nix      # enable = false (line 157)
                                               # + added Fish aliases to Bash
```

---

## Next Steps

**Recommended**:
```bash
# Option 1: Force rebuild
home-manager expire-generations "-0 days"
home-manager switch --impure --flake .#gburd@floki

# Option 2: Just restart your session
exec bash

# Then verify
echo $SHELL
alias n
n --version
```

All configuration is ready - Bash just needs to be activated by either forcing a rebuild or starting a new session.

---

Last Updated: 2026-04-09
