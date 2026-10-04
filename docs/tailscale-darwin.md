# Tailscale on the macOS host (`aws` / `80a99738d7e2`)

The MacBook Air was the one *supportable* host missing from the tailnet.
Nothing was blocking it: Tailscale builds for `aarch64-darwin`, and both
Tailscale and Headscale list macOS as a supported client. It had simply
never been configured. `darwin/_mixins/services/tailscale.nix` now runs the
daemon (a `tailscaled` launchd daemon, verified in the evaluated config).

For contrast, the solnix hosts `dixi`, `dixa` and `dixr` cannot join at all:
they run illumos, which has no Tailscale client. nixpkgs' `tailscale`
declares only Linux and Darwin platforms, Tailscale ships no illumos build,
and Headscale's own client matrix lists Linux, OpenBSD, FreeBSD, Windows,
Android, macOS, iOS and tvOS — no illumos or Solaris. Switching to Headscale
would not change that, because Headscale replaces the control plane only;
nodes still run the official client.

## One-time enrolment (manual, by necessity)

The NixOS hosts self-enrol: `nixos/_mixins/services/tailscale-autoconnect.nix`
reads a reusable auth key from sops and runs `tailscale up` idempotently.
That path does not exist on darwin, for two independent reasons:

- nix-darwin's `services.tailscale` module exposes only `enable`, `package`,
  `magicDNS`, `overrideLocalDns` and `domain` — no auth key, no extra up-flags.
- There is no sops-nix on darwin (see the note in
  `darwin/_mixins/console/ai/default.nix`), so there is nowhere to read the
  key from.

So after `darwin-rebuild switch --flake .#aws`, run once on the Mac:

```sh
# --hostname matters: the OS hostname is 80a99738d7e2, which would be a
# useless tailnet name. Register it as "aws", matching the flake attribute
# and the ~/.ssh/config alias.
sudo tailscale up --hostname=aws --accept-routes
```

That opens a browser to authenticate against the `gregburd@gmail.com`
tailnet. Verify from any other node:

```sh
tailscale status | grep aws
```

To use the reusable key from sops instead of a browser login, read it on a
Linux host and pass it explicitly:

```sh
# on floki
sops -d --extract '["tailscale-auth-key"]' nixos/_mixins/secrets.yaml
# then on the Mac
sudo tailscale up --hostname=aws --accept-routes --auth-key=tskey-...
```

## DNS: deliberately left alone

`services.tailscale.overrideLocalDns` is **not** set. Its own option
description warns that it makes `100.100.100.100` the sole DNS server, so
"all non-MagicDNS queries WILL fail" unless a DNS server is added *and*
`Override local DNS` is enabled in the Tailscale control panel. This host is
a laptop that moves between networks; breaking ordinary DNS to gain MagicDNS
short names is the wrong trade. Reach other nodes by their full
`<host>.tail09c91d.ts.net` name, or by their `100.x` address.

## Not configured here

- `--advertise-exit-node`, which the NixOS hosts set in
  `nixos/_mixins/services/tailscale.nix`. A laptop on hotel or cellular
  networks is a poor exit node, and advertising one invites accidental use.
  Add it to the `tailscale up` line if you ever want it.
- Tailscale SSH. The Mac is reached over ordinary SSH through the `aws`
  alias in `~/.ssh/config`.
