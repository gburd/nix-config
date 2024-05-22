# My NixOS configurations

Here's my NixOS/home-manager config files. Requires [Nix
flakes](https://nixos.wiki/wiki/Flakes).

This work is really a 90% copy/paste from [Tom
Carrio(https://github.com/tcarrio/nix-config) so you'd be much better off
looking at his work than mine while I'm off studying [Nix
Pills](https://nixos.org/guides/nix-pills/) and trying to keep up.

## How to bootstrap

All you need is nix (any version). Run:
```
nix-shell
```

If you already have nix 2.4+, git, and have already enabled `flakes` and
`nix-command`, you can also use the non-legacy command:
```
nix develop
```

`nixos-rebuild --flake .` To build system configurations

`home-manager --flake .` To build user configurations

`nix build` (or shell or run) To build and use packages

`sops` To manage secrets, example:

```
export GPG_TTY=$(tty)
gpgconf --reload gpg-agent
EDITOR=vi sops --config .sops.yaml nixos/_mixins/secrets.yaml
```


## Secrets

For deployment secrets (such as user passwords and server service secrets), I'm
using the awesome [`sops-nix`](https://github.com/Mic92/sops-nix). This keeps
all secrets encrypted with my personal PGP key (stored *only* within a YubiKey I
keep in my safe at home), as well as the relevant systems's SSH host keys and
any other sensitive materials.

On my desktop and laptop, I use `pass` for managing passwords, also encrypted
using (you bet) my PGP key. This same key is also used for mail signing, as well
as for SSH'ing around.  You can find my pub key on
[Keybase.io](https://keybase.io/gregburd) or other information on [my site](https://greg.burd.me).
