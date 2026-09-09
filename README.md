# NixOS, nix-darwin & Home Manager configuration

Multi-host configuration for my workstations, servers, a macOS laptop, and a
handful of build/deploy targets. Requires [Nix flakes](https://nixos.wiki/wiki/Flakes).

`flake.nix` is the single entry point; every host is defined there and built
through the helper constructors in `lib/helpers.nix` (`mkHost`, `mkWslHost`,
`mkDarwin`, `mkHome`, ...). Shared logic lives under `nixos/`, `darwin/`, and
`home-manager/`, each fanning out into `_mixins/`. See `AGENTS.md` for the
architecture map and the host table, and `docs/` for deeper topics
(host-key rotation, pinentry, Bedrock, Rust dev shell).

## Bootstrap

All you need is any version of Nix. From the repo root:

```
nix develop        # flakes enabled (or `nix-shell` for the legacy path)
```

This drops you into `shell.nix` with `home-manager`, `sops`, `age`,
`ssh-to-age`, `git`, and the other tools needed to bring up a machine.

## Applying the configuration

The target type depends on the host.

macOS (nix-darwin, host `aws` = `80a99738d7e2`) - home-manager is a darwin
module here, so `darwin-rebuild` applies both system and user config in one
step:

```
darwin-rebuild build  --flake .#aws     # dry build
darwin-rebuild switch --flake .#aws
```

NixOS (local):

```
sudo nixos-rebuild dry-activate --flake .#floki
sudo nixos-rebuild switch       --flake .#floki
```

Home Manager (standalone, on NixOS hosts):

```
home-manager switch -b backup --flake .#gburd@floki
```

NixOS (remote): `./deploy.sh <host>[,<host2>...]`, or `nixos-rebuild` with
`--target-host`/`--build-host`.

EC2 PostgreSQL perf fleet (Colmena): `colmena apply --on @perf` after setting
each node's `deployment.targetHost`.

Convenience wrappers: `task rebuild-host` / `task rebuild-all` (OS-aware; see
`Taskfile.yml`) and the `rebuild-*` fish aliases.

Before switching, validate with `scripts/validate-config.sh` (fmt + statix +
`nix flake check` + dry builds) or `nix flake check`. CI enforces nixpkgs-fmt,
statix, and deadnix on pull requests.

Custom packages: `nix build .#<pkg>` (also `nix shell`, `nix run`).

## Secrets

Deployment secrets (user passwords, service secrets) use
[`sops-nix`](https://github.com/Mic92/sops-nix), encrypted with a personal PGP
key stored only on a YubiKey, plus each system's SSH host keys. See `.sops.yaml`
and `secrets/`.

```
export GPG_TTY=$(tty)
gpgconf --reload gpg-agent
EDITOR=vi sops --config .sops.yaml nixos/_mixins/secrets.yaml
```

On the desktop and laptop I use `pass` for interactive passwords, encrypted with
the same PGP key (also used for mail signing and SSH). Public key on
[Keybase.io](https://keybase.io/gregburd); more at [my site](https://greg.burd.me).
