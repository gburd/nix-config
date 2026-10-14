# Tailscale on the macOS host (`aws` / `80a99738d7e2`)

The Mac joins the tailnet through our own Headscale server,
`https://headscale.burd.me`, and never through tailscale.com. It is the
employer's machine, and policy blocks it from talking to Tailscale's
servers. The client is the stock open-source `tailscaled`, run as a launchd
daemon by `darwin/_mixins/services/tailscale.nix`. The Headscale server is
in `~/ws/fly-apps/headscale`, on fly.io.

None of these paths touch a Tailscale-operated host:

| Path | Where it goes | Set by |
|---|---|---|
| Coordination | `headscale.burd.me` | `--login-server` at enrolment (below) |
| Relay (DERP) | Headscale's embedded DERP, region 999 | server config `derp.urls: []` |
| Log upload | nowhere | `TS_NO_LOGS_NO_SUPPORT=true` on the daemon |
| Captive-portal probes | nowhere | `TS_DISABLE_FEATURE=captiveportal` on the daemon |

`tailscaled` uploads logs to `log.tailscale.io` whatever control server it
uses. nix-darwin's module has no `disableUpstreamLogging`, so the env var
that NixOS's option sets is put on the launchd daemon directly. Captive-portal
detection would otherwise probe `controlplane.tailscale.com` and
`login.tailscale.com` whenever STUN looks slow.

The solnix hosts `dixi`, `dixa` and `dixr` cannot join at all. They run
illumos, and no Tailscale client exists for it. Headscale changes only the
control server, so it does not help there.

## Enrolment (manual, once)

The NixOS hosts self-enrol from a sops auth key
(`nixos/_mixins/services/tailscale-autoconnect.nix`). The Mac cannot, for
two reasons. nix-darwin's `services.tailscale` exposes only `enable`,
`package`, `magicDNS`, `overrideLocalDns` and `domain`, with no auth key and
no up-flags. There is also no sops-nix on darwin.

After `darwin-rebuild switch --flake .#aws`, run on the Mac:

```sh
# --hostname: the OS hostname 80a99738d7e2 is a useless tailnet name.
sudo tailscale up --login-server https://headscale.burd.me --hostname=aws --accept-routes
```

It prints a URL of the form
`https://headscale.burd.me/register/hskey-authreq-<24 chars>`. Opening it
only shows the approval command; nothing is approved in the browser. Approve
from any machine with the fly session:

```sh
flyctl ssh console -a burd-headscale -C "headscale auth register --auth-id hskey-authreq-<...> --user gburd"
```

That syntax is from the v0.29.5 binary. `--user` takes the user name here.
`headscale nodes register --user gburd --key <id>` still works too, but it
prints a deprecation notice pointing at `auth register`.

If the Mac was ever logged in to tailscale.com, run `sudo tailscale logout`
first. `up` refuses to change `--login-server` on a running node without
`--force-reauth`.

Verify:

```sh
tailscale status                     # on the Mac: peers listed, no "Logged out"
tailscale debug derp-map | grep -i regionid   # only 999, no Tailscale regions
flyctl ssh console -a burd-headscale -C "headscale nodes list"
```

## DNS

Headscale's `dns.base_domain` is `ts.burd.me`, so tailnet hosts are
`<name>.ts.burd.me`. `tailscaled` writes `/etc/resolver/ts.burd.me` itself,
pointing at `100.100.100.100`, and macOS uses it for that suffix only.
Nothing else in the system's DNS changes.

Do not add `environment.etc."resolver/ts.burd.me"` to the Nix config.
nix-darwin would make it a symlink into `/etc/static`. `tailscaled` writes
resolver files through Go's `os.Root`, which refuses to follow that symlink
("path escapes from parent"). Its DNS config step then fails and stops
before cleaning up stale resolver files. nix-darwin's own `resolver/ts.net`
does no harm: it only matches the SaaS suffix.

`services.tailscale.overrideLocalDns` stays off, and the module asserts this.
It would make `100.100.100.100` the only resolver and displace the corporate
DNS. The Headscale server also sets `dns.override_local_dns: false`.

NextDNS profile `362f8c` is reported to block `controlplane.tailscale.com`,
but a DoH query to it on 2026-10-14 returned real addresses (192.200.0.x;
a known ad domain returned `0.0.0.0`). Under Headscale it does not matter
either way. What matters is that the profile never blocks
`headscale.burd.me`, or every node loses its control server.

Do not run `tailscale netcheck` on the Mac before enrolment. With no DERP
map from `tailscaled`, it fetches Tailscale's map from
`controlplane.tailscale.com`.

## Not configured here

- `--advertise-exit-node`. A laptop on hotel or cellular networks is a poor
  exit node, and advertising one invites accidental use.
- Tailscale SSH. The Mac is reached over ordinary SSH through the `aws`
  alias in `~/.ssh/config`.
