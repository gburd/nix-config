{ config, lib, pkgs, inputs, ... }:
# agent-sandbox — run a coding agent (or any command) in an isolated
# environment, TRANSPARENT to the agent (no agent flags/cooperation, not
# vendor-specific). A rogue/confused agent can't touch things it shouldn't
# (SSH keys, sops secrets, ~/.aws, the Bedrock bearer token, other projects,
# the rest of $HOME); a runaway child is memory-capped and made the OOM
# killer's first victim so it dies in the sandbox (no cascade to terminals).
#
# TIERS
#   firejail (default, RECOMMENDED for host agents) — namespace sandbox that
#     SHARES the host /nix store, so host agent binaries (pi/claude/codex/
#     maki/hermes, all Nix/npm) run unchanged. Whitelists cwd (rw); blocks
#     SSH keys, secrets, ~/.aws, the bearer token. Shares the host network
#     namespace so the agent reaches the loopback LiteLLM gateway (the single
#     broker to AWS/Bedrock = the controlled cloud path).
#   docker — container isolation. Host agents need the host /nix + ~/.npm +
#     PATH, which this mounts read-only (best-effort); heavier, use for
#     untrusted/containerized toolchains rather than the native agents.
#   vm — full QEMU VM (hardware-virtualised kernel isolation, strongest
#     tier). Boots a minimal NixOS guest (nixosConfigurations.agent-vm) with
#     the project shared in + the host LiteLLM gateway reachable at
#     10.0.2.2:4000; runs the command, powers off.
#
# --aws is intentionally NOT how gateway-routed agents reach AWS: they use the
# host LiteLLM gateway (127.0.0.1:4000), and --aws's private netns can't see
# it. --aws is only for a tool making DIRECT AWS calls with its own creds.
let
  cfg = config.programs.ai.sandbox;
  inherit (lib) mkEnableOption mkOption mkIf types;
  home = config.home.homeDirectory;

  # Sensitive paths blocked in EVERY profile. The ~/.ssh handling differs by
  # profile (default blocks the whole dir; the --ssh profile blocks only the
  # private keys), so it's NOT in this shared base.
  commonBase = ''
    caps.drop all
    nonewprivs
    seccomp
    noroot
    # --- Hard-block sensitive paths (agent must never read these) ---
    # NOTE: ~/.aws is NOT blocked here — it's added by the profiles below so
    # the --aws-profile creds profile (agent-aws-creds.profile) can omit it.
    blacklist ${home}/.gnupg
    blacklist ${home}/.config/sops
    blacklist ${home}/.config/sops-nix
    blacklist ${home}/.config/claude-code/.bearer_token
    blacklist ${home}/.password-store
    blacklist ${home}/.netrc
    read-only ${home}/.gitconfig
    private-tmp
    private-dev
  '';

  # SSH-blocking fragment shared by the default + aws-creds profiles: no
  # ~/.ssh, no agent socket, no SSH_AUTH_SOCK env. (--ssh uses sshProfile
  # instead, which permits the agent socket.)
  noSshFragment = ''
    blacklist ${home}/.ssh
    blacklist /run/user/*/gcr/ssh
    blacklist /run/user/*/keyring/ssh
    blacklist /run/user/*/ssh-agent*
    rmenv SSH_AUTH_SOCK
  '';

  # Default: no SSH, and ~/.aws fully blocked.
  commonProfile = ''
    ${commonBase}
    blacklist ${home}/.aws
    ${noSshFragment}
  '';

  # --ssh variant: allow SSH via the forwarded ssh-agent SOCKET only. Block
  # every PRIVATE KEY file individually (so a rogue agent still can't read/
  # exfiltrate key material), but leave ~/.ssh/config (host aliases) and
  # known_hosts readable and let the agent socket do the actual auth. The
  # launcher binds $SSH_AUTH_SOCK and keeps the SSH_AUTH_SOCK env var.
  sshProfile = ''
    ${commonBase}
    blacklist ${home}/.aws
    # Block every private key inside ~/.ssh; the forwarded ssh-agent socket
    # does the auth. We do NOT whitelist ~/.ssh/config or known_hosts: they
    # are nix-store symlinks (root-owned, 0444) that trip SSH's strict
    # "Bad owner or permissions" check. Connect by full hostname / Tailscale
    # name (host aliases from ~/.ssh/config aren't available in the sandbox);
    # host-key checking uses accept-new. This keeps the sandbox simple and
    # never exposes key material.
    blacklist ${home}/.ssh/id_*
    blacklist ${home}/.ssh/*.pem
    blacklist ${home}/.ssh/*_ed25519
    blacklist ${home}/.ssh/*_rsa
    # The system /etc/ssh/ssh_config Includes a systemd ssh-proxy drop-in
    # (a root-owned nix-store file). Inside firejail's user namespace the
    # ownership check on that Included file fails, so OpenSSH aborts with
    # "Bad owner or permissions" (fatal). Blacklist the drop-in dir so ssh
    # skips it; the agent socket + accept-new host-key policy suffice.
    blacklist /nix/store/*/lib/systemd/ssh_config.d
    ignore net none
  '';

  agentProfile = pkgs.writeText "agent.profile" ''
    ${commonProfile}
    # Share the host network namespace so the agent reaches the LiteLLM
    # gateway on 127.0.0.1:4000. (A private netns has its own loopback and
    # can't see the host gateway; egress restriction, if wanted, belongs at
    # the host firewall / gateway, not here.)
    ignore net none
  '';

  agentSshProfile = pkgs.writeText "agent-ssh.profile" sshProfile;

  # --aws-profile variant: like the default profile (no SSH) but WITHOUT the
  # ~/.aws blacklist, so the launcher's --whitelist ~/.aws takes effect (a
  # cmdline whitelist can't override a profile blacklist). Only used when
  # --aws-profile <name> is passed; scoped to reading ~/.aws for that account.
  agentCredsProfile = pkgs.writeText "agent-aws-creds.profile" ''
    ${commonBase}
    ${noSshFragment}
    ignore net none
  '';

  awsNetfilter = pkgs.writeText "agent-aws.net" ''
    *filter
    :INPUT DROP [0:0]
    :FORWARD DROP [0:0]
    :OUTPUT DROP [0:0]
    -A INPUT -i lo -j ACCEPT
    -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    -A OUTPUT -o lo -j ACCEPT
    -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    -A OUTPUT -p udp --dport 53 -j ACCEPT
    -A OUTPUT -p tcp --dport 53 -j ACCEPT
    -A OUTPUT -p tcp --dport 443 -j ACCEPT
    COMMIT
  '';

  agentAwsProfile = pkgs.writeText "agent-aws.profile" ''
    ${commonProfile}
    # Own network namespace + egress filter (DNS + HTTPS only) for DIRECT-AWS
    # tools. The host 127.0.0.1:4000 gateway is NOT reachable here. The --net
    # device is injected at runtime (auto-detected default route).
    netfilter ${awsNetfilter}
  '';

  usage = ''
    agent-sandbox -- run a command isolated (firejail/docker/vm).

    USAGE:
      agent-sandbox [OPTIONS] <cmd> [args...]
      agent-sandbox [OPTIONS] -- <cmd> [args...]

    OPTIONS:
      --tier <t>   firejail (default) | docker | vm | ec2
      --mem <size> memory cap, e.g. 8G / 512M (default: ${cfg.defaultMemMax})
      --aws        DIRECT-AWS mode: private netns + DNS/HTTPS-only egress.
                   BREAKS gateway-routed agents (pi/claude/codex/maki/hermes)
                   because the host LiteLLM gateway is unreachable in a private
                   netns. Use only for tools hitting AWS with their own creds.
      --aws-profile <name>
                   Grant the sandbox READ-ONLY access to ~/.aws and set
                   AWS_PROFILE=<name>, so the agent can use that AWS account
                   (e.g. numa-bench). Default blocks ~/.aws entirely; this is
                   opt-in per invocation and scoped to the one named profile.
                   Works alongside the normal (gateway) tier, unlike --aws.
                   Also works with --tier ec2: pushes just that ONE profile's
                   credentials to the box itself (via `aws configure
                   export-credentials`, so SSO/role-assumption profiles
                   resolve to plain keys before copying -- the box has
                   neither your SSO cache nor any assumed-role chain) and
                   exports AWS_PROFILE in the tmux session, so an agent
                   running INSIDE the sandbox (e.g. following the
                   aws-benchmark skill to launch its own EC2 instances for a
                   benchmark) has something to authenticate with. Without
                   this flag an ec2-tier sandbox has NO AWS credentials at
                   all -- confirmed live gap, the box never had ~/.aws
                   regardless of what's configured on the connecting host.
      --ssh        Allow outbound SSH: forwards the ssh-agent SOCKET into the
                   sandbox so the agent can SSH to LAN hosts / EC2 / etc. using
                   your loaded keys. Private key FILES stay blocked (the agent
                   signs challenges; keys cannot be read/exfiltrated). Requires
                   a running ssh-agent with keys loaded (ssh-add -l). Connect
                   by full hostname / Tailscale name (~/.ssh/config aliases
                   are not available in the sandbox); use
                   StrictHostKeyChecking=accept-new on first connect.
      -h, --help   this help.

    --tier ec2 usage:
      agent-sandbox --tier ec2 [up|connect|down|status] [workspace] [--terminate]
        [--arch x86_64|aarch64] [--instance-type TYPE] [-- cmd...]
      A real EC2 instance (NixOS AMI), not a local sandbox: the whole VM IS
      the isolation boundary. State lives in AWS instance tags
      (Name=asx-<workspace>, default workspace = current dir name) so ANY
      host with the numa AWS profile + your SSH key can reconnect to the
      SAME box. Project data + Nix builds live on the instance's local
      NVMe instance-store (fast, free with the instance), not the small
      EBS root volume.
        up       launch (or start, if stopped) the workspace, wait for SSH.
        connect  (default) up + bidirectional unison sync + ssh in; syncs
                 back on disconnect. With a -- separator + a command, runs
                 that command instead of an interactive shell.
        down     sync back, then STOP the instance (EBS persists, cheap,
                 resume later). --terminate destroys it (EBS gone too).
        status   show instance id / state / IP for the workspace, if any.
      --arch (up/connect only, default x86_64): aarch64 launches a Graviton
        instance instead. --instance-type overrides the arch's configured
        default entirely (must still match --arch's actual architecture).
      Config: programs.ai.sandbox.ec2.{region,instanceTypeX86,instanceTypeArm,volumeSizeGb,awsProfile}.
      One-time on first up: creates a dedicated key pair + security group
      (SSH from your current IP only) via the configured AWS profile. That
      IP allow-list is refreshed on every up/connect/down too (not just
      the first time) -- your ISP's IP can change between sessions, which
      otherwise silently locks out reconnecting to a box left running.
      Every up/connect also refreshes a stable ssh alias (asx-<workspace>,
      in ~/.ssh/agent-sandbox-ec2.conf) pointed at the box's CURRENT IP
      (EC2 assigns a new one on every start) -- use it for a plain
      `ssh asx-<workspace>`, VSCode's `code --remote ssh-remote+asx-<workspace>
      <path>`, or Zed's ssh_connections (host: asx-<workspace>), instead of
      chasing the IP by hand.
      Optionally also joins your Tailscale tailnet: put a REUSABLE +
      EPHEMERAL Tailscale auth key at ~/.config/agent-sandbox/tailscale.key
      (sops-deployed; see floki.nix's tailscale/agent-sandbox-key secret)
      and each box joins the tailnet as asx-<workspace> on first boot.
      Ephemeral means Tailscale itself removes the device on disconnect --
      terminating the instance is the only teardown step needed. No key
      configured -> tailscale-join.service is a harmless no-op.

    EXAMPLES:
      agent-sandbox pi                 # isolate pi (recommended: firejail)
      agent-sandbox --mem 8G claude    # cap memory
      agent-sandbox -- bash            # inspect the sandbox interactively
      agent-sandbox --tier ec2 connect             # up+sync+ssh, workspace=$(basename $PWD)
      agent-sandbox --tier ec2 connect -- pi        # sync, ssh in, run pi, sync back
      agent-sandbox --tier ec2 down                 # sync back, stop (cheap)
      agent-sandbox --tier ec2 down --terminate     # sync back, destroy
      agent-sandbox --tier docker mycmd
      agent-sandbox --ssh claude       # allow SSH out (agent socket, not keys)

    ISOLATION (firejail tier): cwd is read-write; ~/.ssh, ~/.aws, the Bedrock
    bearer token, sops secrets, password-store and other ~/ws projects are
    blocked; the agent reaches AWS only through the loopback LiteLLM gateway.
    A runaway is memory-capped (--mem) and killed first by the OOM killer, so
    it dies in the sandbox instead of taking down your terminals.
  '';

  gatewayRouted = "pi claude codex maki hermes kiro";

  # pkgs set for each arch the ec2 tier supports. aarch64 needs its OWN
  # nixpkgs evaluation (not floki's native x86_64 one) so
  # mkEc2ConfigTemplate's store-path references (git, nix-ld's closure)
  # are real aarch64 binaries the EC2 box can actually run/build against --
  # confirmed the hard way: without this, the generated configuration.nix
  # embeds an x86_64 ExecStart path on an arm64 box.
  pkgsFor = {
    x86_64 = pkgs;
    aarch64 = inputs.nixpkgs.legacyPackages.aarch64-linux;
  };

  # NixOS config fragment for the ec2 tier's one-time gburd-user + sudo
  # bootstrap on a stock NixOS AMI (which only has root). AUTHKEY is
  # substituted at runtime (sed) -- keeping it out of this static template
  # avoids Nix-level string-escaping through TWO more layers (a shell
  # heredoc AND ANOTHER shell over ssh).
  #
  # The mount-instance-nvme script is INLINED as a real script = '' ... ''
  # in the generated module (built with the box's OWN pkgs when THAT
  # config gets evaluated by nixos-rebuild, not floki's) rather than
  # referenced as a separate writeShellScript by /nix/store path. Tried
  # the separate-derivation approach first and hit two real problems live:
  # (1) a path built on floki doesn't exist in the BOX's store, and 'nix
  # copy'-ing it over there works but isn't a tracked dependency of
  # anything on the box, so a routine `nix-collect-garbage -d` (e.g. to
  # free disk after a too-small EBS root) reaps it -- the unit then fails
  # with "Unable to locate executable" on the NEXT boot; (2) it needed a
  # SEPARATE per-arch pkgs set threaded through just to get the right-arch
  # binary, doubling the plumbing. Inlining it means it's built ON the
  # box, from the box's own nixpkgs, as a normal part of its own system
  # closure -- a real GC root, no copy step, no cross-arch concern at all
  # (the whole point of generating x86_64/aarch64 variants HERE is just so
  # the generated Nix SOURCE embeds the right nixpkgs channel/config,
  # which matters for other packages like pkgs.git).
  #
  # Nix's escape for a literal '' inside an outer '' ... '' is ${"''"} (two
  # single quotes, NOT escaped with a backslash) -- used below for the
  # inner script = ''...''; delimiters. Nesting them unescaped hits Nix's
  # "inner '' terminates the outer string early" rule (confirmed the hard
  # way: nix fmt then "reformats" the corrupted leftover parse into
  # garbage like "set - eu").
  mkEc2ConfigTemplate = arch:
    let p = pkgsFor.${arch}; in
    p.writeText "agent-sandbox-ec2-configuration-${arch}.nix" ''
      { modulesPath, pkgs, ... }: {
        imports = [ "''${modulesPath}/virtualisation/amazon-image.nix" ];
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        # git: needed by home-manager's build itself (programs.ai.skills
        # fetches a skills repo at eval/build time) -- without it on PATH,
        # 'home-manager switch' fails evaluating home.activation before it
        # ever gets to deploying anything. Everything else the agents need
        # comes in through home-manager/console/ai itself.
        environment.systemPackages = [ pkgs.git ];
        # nix-ld: uv/uvx (used by programs.ai.skills' SkillSpector gate) can
        # download its OWN standalone Python build, a generic dynamically-
        # linked binary that fails on NixOS without this ("NixOS cannot run
        # dynamically linked executables... nix.dev/permalink/stub-ld" --
        # confirmed live: the gate then treats EVERY skill as blocked, since
        # it can't tell a real risk finding from uvx failing to even run).
        # Our other hosts already set this (nixos/_mixins/workstations/common.nix).
        programs.nix-ld.enable = true;
        users.users.gburd = {
          isNormalUser = true;
          uid = 1001;
          shell = "/run/current-system/sw/bin/bash";
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [ "@AUTHKEY@" ];
        };
        security.sudo.extraRules = [
          { users = [ "gburd" ]; commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ]; }
        ];

        # Join the tailnet with a DEDICATED, ephemeral auth key -- see
        # tailscale/agent-sandbox-key in floki.nix's sops secrets for why
        # this is a separate key from the one real hosts use. --ssh
        # exposes Tailscale SSH too (belt-and-suspenders; the agent-sandbox
        # CLI itself still connects via the security-group-gated public IP,
        # not this), --hostname makes the box findable in the tailnet by
        # its workspace name. Ephemeral means Tailscale ITSELF removes this
        # node once it disconnects -- terminate the instance and the device
        # entry disappears with zero explicit teardown code needed.
        services.tailscale.enable = true;
        systemd.services.tailscale-join = {
          description = "Join the tailnet with the agent-sandbox ephemeral key";
          after = [ "tailscaled.service" "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [ pkgs.tailscale pkgs.jq ];
          script = ${"''"}
            TSKEY="@TSKEY@"
            if [ -z "$TSKEY" ]; then
              echo "tailscale-join: no key configured (programs.ai.sandbox ec2 tier), skipping" >&2
              exit 0
            fi
            for _ in 1 2 3 4 5 6 7 8 9 10; do
              tailscale status >/dev/null 2>&1 && break
              sleep 1
            done
            state=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // "Unknown"')
            if [ "$state" = "Running" ]; then
              exit 0
            fi
            tailscale up --auth-key="$TSKEY" --ssh --hostname="@TSHOSTNAME@" --accept-routes
          ${"''"};
        };

        # Local NVMe instance-store: format + mount at /mnt/nvme, then
        # BIND MOUNT gburd's $HOME/ws (the project tree) onto it, and
        # relocate Nix's build scratch there too -- project I/O and Nix
        # builds run on fast, free-with-the-instance local SSD, not the
        # (much smaller) EBS root volume. ~/ws is a real directory (bind
        # mount), not a symlink -- deliberately, so every tool (unison,
        # git, ssh, agents) sees an ordinary path with no special-casing.
        # A systemd service, not fileSystems=: the disk doesn't exist
        # until the instance actually boots on NVMe-capable hardware, and
        # formatting must happen before the FIRST mount, not on every boot
        # of a stopped/restarted instance (idempotent: skips mkfs if a
        # filesystem is already there, skips re-binding if ~/ws is already
        # mounted). Detected by NVMe model string "Amazon EC2 NVMe Instance
        # Storage", the same method Amazon's own udev rules
        # (amazon-ec2-utils) use to tell it apart from the EBS root --
        # robust across instance families/generations, unlike hardcoding a
        # /dev/nvme?n1 index (varies by boot order).
        systemd.services.mount-instance-nvme = {
          description = "Format (if needed) and mount local NVMe instance-store at /mnt/nvme";
          wantedBy = [ "multi-user.target" ];
          before = [ "multi-user.target" ];
          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [ pkgs.util-linux pkgs.e2fsprogs pkgs.gnugrep pkgs.coreutils ];
          script = ${"''"}
            set -eu
            DEV=""
            for d in /sys/class/nvme/*/; do
              [ -r "$d/model" ] || continue
              model=$(cat "$d/model" 2>/dev/null || true)
              case "$model" in
                *"Instance Storage"*)
                  ns=$(ls "$d" | grep -m1 '^nvme[0-9]*n[0-9]*$' || true)
                  [ -n "$ns" ] && DEV="/dev/$ns"
                  ;;
              esac
              [ -n "$DEV" ] && break
            done
            if [ -z "$DEV" ]; then
              echo "mount-instance-nvme: no local NVMe instance-store found; /mnt/nvme will not exist." >&2
              exit 0
            fi
            mkdir -p /mnt/nvme
            if ! blkid "$DEV" >/dev/null 2>&1; then
              echo "mount-instance-nvme: formatting $DEV (ext4)..."
              mkfs.ext4 -F -L nvme-scratch "$DEV"
            fi
            mountpoint -q /mnt/nvme || mount "$DEV" /mnt/nvme
            mkdir -p /mnt/nvme/ws /mnt/nvme/nix-build-tmp
            chown gburd:users /mnt/nvme/ws
            # /mnt/nvme itself stays root:root 0755 (mount's own default),
            # NOT world-writable -- nix.settings.build-dir (below) walks
            # the whole parent chain and REFUSES a world-writable ancestor
            # ("not allowed for security"), confirmed live. Only the two
            # subdirs anyone actually writes to need their own ownership:
            # ws (gburd's project tree) and nix-build-tmp (root, since
            # only the nix-daemon writes there).
            chown root:root /mnt/nvme/nix-build-tmp
            chmod 0755 /mnt/nvme/nix-build-tmp
            # ~/ws is a BIND MOUNT of /mnt/nvme/ws, not a symlink -- every
            # tool (unison, git, ssh, agents) sees a completely normal
            # directory at /home/gburd/ws (readlink -f/stat show nothing
            # special, confirmed), while the actual storage lives on fast
            # NVMe. gburd's home dir exists by now (user creation happens
            # during system activation, before services start). Idempotent:
            # mountpoint check skips re-binding if already mounted (e.g.
            # this oneshot re-running on an instance restart). Migration
            # from an older boot's symlink (a previous version of this
            # script used ln -sfn instead of a bind mount): unlink only
            # removes an actual symlink, never touches a real directory.
            if [ -L /home/gburd/ws ]; then
              unlink /home/gburd/ws
            fi
            mkdir -p /home/gburd/ws
            chown gburd:users /home/gburd/ws
            mountpoint -q /home/gburd/ws || mount --bind /mnt/nvme/ws /home/gburd/ws
          ${"''"};
        };

        # Nix builds (git.nix's cargo/rustc, home-manager's own derivations,
        # etc.) land on NVMe too, not the small EBS root. mkForce: amazon-
        # image.nix may set its own default.
        nix.settings.build-dir = pkgs.lib.mkForce "/mnt/nvme/nix-build-tmp";
      }
    '';
  ec2ConfigTemplateX86 = mkEc2ConfigTemplate "x86_64";
  ec2ConfigTemplateArm = mkEc2ConfigTemplate "aarch64";

  agent-sandbox = pkgs.writeShellApplication {
    name = "agent-sandbox";
    # firejail must be the SUID wrapper at /run/wrappers/bin/firejail
    # (programs.firejail.enable), NOT the non-SUID nixpkgs store binary.
    runtimeInputs = [ pkgs.coreutils pkgs.docker_29 pkgs.iproute2 pkgs.iptables pkgs.qemu_kvm pkgs.awscli2 pkgs.unison pkgs.openssh pkgs.jq pkgs.systemd ];
    # SC2016: fires on the embedded --help/usage TEXT (a literal, static
    # string passed through lib.escapeShellArg into a single-quoted printf
    # argument -- correct and intentional, not code expecting expansion).
    excludeShellChecks = [ "SC2016" ];
    text = ''
      set -euo pipefail
      # Preserve the CALLER's PATH: writeShellApplication resets PATH to its
      # runtimeInputs, which drops ~/.nix-profile/bin (where the agent
      # wrappers live) and ~/.pi/agent/bin etc. Capture it before use.
      CALLER_PATH="''${PATH}"
      # Re-export PATH into our OWN environment (not via `env PATH=... argv`):
      # firejail caps any single argv element at 4128 bytes, and a project
      # devshell's PATH (build-tool bins) can exceed that -> "too long
      # argument" abort. Env vars ride via envp, not argv, so this has no
      # such cap; firejail's child inherits it like any other env var.
      export PATH="$CALLER_PATH"
      # Every gateway-routed agent's OWN settings/session dir, plus its
      # LiteLLM virtual-key file (read-only — an agent must never rotate its
      # own key). Without these whitelisted, an agent can reach the gateway
      # over the network but has no key to authenticate with ("No API key
      # found") and no settings/session state to read or write. Safe to list
      # unconditionally: firejail --whitelist on a path that doesn't exist
      # yet is a silent no-op, not an error.
      AGENT_DIRS=(
        --whitelist="${home}/.pi"
        --whitelist="${home}/.claude"
        --whitelist="${home}/.codex"
        --whitelist="${home}/.hermes"
        --whitelist="${home}/.local/share/maki"
        --whitelist="${home}/.config/maki"
        --whitelist="${home}/.config/litellm/keys"
        --read-only="${home}/.config/litellm/keys"
      )
      TIER=firejail
      MEM="${cfg.defaultMemMax}"
      AWS=0
      SSH=0
      AWS_PROFILE_NAME=""
      while [ $# -gt 0 ]; do
        case "$1" in
          -h|--help) printf '%s' ${lib.escapeShellArg usage}; exit 0 ;;
          --tier) TIER="$2"; shift 2 ;;
          --mem)  MEM="$2"; shift 2 ;;
          --aws)  AWS=1; shift ;;
          --aws-profile) AWS_PROFILE_NAME="$2"; shift 2 ;;
          --ssh)  SSH=1; shift ;;
          --)     shift; break ;;
          -*)     echo "agent-sandbox: unknown flag $1 (try --help)" >&2; exit 2 ;;
          *)      break ;;
        esac
      done
      [ $# -gt 0 ] || { printf '%s' ${lib.escapeShellArg usage} >&2; exit 2; }

      PROJECT="$PWD"

      # --aws-profile <name>: deliberately grant the sandbox read-only access
      # to ~/.aws + set AWS_PROFILE, so the agent can use THAT named account
      # (e.g. numa-bench). Default keeps ~/.aws fully blocked. This is opt-in
      # per invocation and scoped to the one profile you name.
      AWS_FJ=()      # extra firejail args (whitelist ~/.aws ro)
      AWS_ENV=()     # extra env for the agent (AWS_PROFILE=…)
      if [ -n "$AWS_PROFILE_NAME" ]; then
        AWS_FJ=(--whitelist="${home}/.aws" --read-only="${home}/.aws")
        AWS_ENV=("AWS_PROFILE=$AWS_PROFILE_NAME")
      fi

      mem_bytes() {
        local v n unit
        v=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
        n=$(printf '%s' "$v" | tr -dc '0-9')
        unit=$(printf '%s' "$v" | tr -dc 'GMK')
        case "$unit" in
          G) echo $(( n * 1024 * 1024 * 1024 )) ;;
          M) echo $(( n * 1024 * 1024 )) ;;
          K) echo $(( n * 1024 )) ;;
          *) echo "$n" ;;
        esac
      }

      case "$TIER" in
        firejail)
          # Resolve firejail: NixOS provides a SUID wrapper at
          # /run/wrappers/bin/firejail (required — the store binary can't
          # create /run/firejail's lockfile); Fedora/other distros use the
          # system SUID binary on PATH (/usr/bin/firejail on arnold).
          if [ -x /run/wrappers/bin/firejail ]; then
            FIREJAIL=/run/wrappers/bin/firejail
          elif command -v firejail >/dev/null 2>&1; then
            FIREJAIL=$(command -v firejail)
          else
            echo "agent-sandbox: firejail not found (NixOS: programs.firejail.enable;" >&2
            echo "  Fedora: sudo dnf install firejail)." >&2
            exit 3
          fi
          if [ "$AWS" -eq 1 ]; then
            # --aws puts the sandbox in a PRIVATE netns for egress filtering.
            # Gateway-routed agents (pi/claude/…) reach models via the host
            # LiteLLM gateway at 127.0.0.1:4000, which is UNREACHABLE from a
            # private netns — so --aws + such an agent can never work. Hard-
            # block it (a 3s warning that then fails is worse UX).
            for g in ${gatewayRouted}; do
              if [ "$1" = "$g" ]; then
                echo "agent-sandbox: --aws is incompatible with '$1'." >&2
                echo "  '$1' reaches models through the host LiteLLM gateway" >&2
                echo "  (127.0.0.1:4000), which a private-netns (--aws) sandbox can't see." >&2
                echo "  Run 'agent-sandbox $1' (no --aws) — the default tier still blocks" >&2
                echo "  SSH keys/secrets/AWS creds. --aws is only for tools making DIRECT" >&2
                echo "  AWS calls with their own credentials." >&2
                exit 2
              fi
            done
            NETDEV=$(ip -o route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
            NETDEV="''${NETDEV:-${cfg.awsNetDevice}}"
            if [ -z "$NETDEV" ]; then
              echo "agent-sandbox: --aws could not auto-detect the uplink device." >&2
              echo "  Set programs.ai.sandbox.awsNetDevice to your interface (ip link)." >&2
              exit 3
            fi
            exec systemd-run --user --scope --collect --quiet \
              -p "MemoryMax=$MEM" -p MemorySwapMax=0 -- \
              "$FIREJAIL" --quiet \
              --profile="${home}/.config/firejail/agent-aws.profile" \
              --net="$NETDEV" \
              --whitelist="${home}/.nix-profile" \
              --whitelist="${home}/.local/state/nix" \
              --whitelist="${home}/.npm" \
              "''${AGENT_DIRS[@]}" \
              --oom=900 \
              --private-cwd="$PROJECT" --whitelist="$PROJECT" \
              "$@"
          fi
          # Default: share host /nix + network; isolate the filesystem + cap
          # memory via a REAL cgroup (systemd-run --scope -p MemoryMax=),
          # not firejail's own --rlimit-as. --rlimit-as limits virtual
          # ADDRESS SPACE, which Node/V8 (pi/claude/codex/maki/hermes are all
          # Node) reserves far more of than it ever touches physically --
          # pi alone needs ~24G of --rlimit-as just to start (a WASM linear-
          # memory reservation in its HTTP client), well past any cap meant
          # to catch a runaway. A cgroup MemoryMax tracks actual RSS + page
          # cache (including tmpfs: /tmp and /dev/shm inside the sandbox are
          # tmpfs, uncapped by rlimit-as, but DO count against a cgroup) --
          # verified: pi runs fine at a 1G cgroup cap; a real runaway gets
          # OOM-killed by the kernel, scoped to just this cgroup (confirmed
          # via journalctl, no impact outside it). MemorySwapMax=0 keeps a
          # runaway from just paging out instead of dying. --oom=900 (still
          # firejail's own flag) is complementary: it raises the process's
          # oom_score_adj so if the HOST's global OOM killer ever fires for
          # an unrelated reason, this is the first thing it reaps too.
          # Whitelist the nix-profile dirs so the agent wrappers resolve, and
          # re-export the caller's PATH (writeShellApplication clobbered it).
          #
          # --ssh: allow outbound SSH via the forwarded ssh-agent SOCKET only
          # (the agent-ssh profile blocks private-key FILES but permits
          # config/known_hosts; auth is done by the agent, which signs
          # challenges without exposing key material). Bind the socket dir and
          # keep SSH_AUTH_SOCK in the child env.
          if [ "$SSH" -eq 1 ]; then
            SOCK="''${SSH_AUTH_SOCK:-}"
            if [ -z "$SOCK" ] || [ ! -S "$SOCK" ]; then
              echo "agent-sandbox: --ssh needs a running ssh-agent (SSH_AUTH_SOCK unset/invalid)." >&2
              echo "  Load keys with 'ssh-add' first; the sandbox uses the agent, not key files." >&2
              exit 2
            fi
            exec systemd-run --user --scope --collect --quiet \
              -p "MemoryMax=$MEM" -p MemorySwapMax=0 -- \
              "$FIREJAIL" --quiet \
              --profile="${home}/.config/firejail/agent-ssh.profile" \
              --whitelist="${home}/.nix-profile" \
              --whitelist="${home}/.local/state/nix" \
              --whitelist="${home}/.npm" \
              "''${AGENT_DIRS[@]}" \
              --whitelist="$SOCK" \
              "''${AWS_FJ[@]}" \
              --oom=900 \
              --private-cwd="$PROJECT" --whitelist="$PROJECT" \
              env "''${AWS_ENV[@]}" SSH_AUTH_SOCK="$SOCK" "$@"
          fi
          # --aws-profile uses the creds profile (no ~/.aws blacklist) so the
          # whitelist below actually exposes ~/.aws; otherwise the default
          # profile keeps ~/.aws blocked.
          DEFAULT_PROFILE="${home}/.config/firejail/agent.profile"
          if [ -n "$AWS_PROFILE_NAME" ]; then
            DEFAULT_PROFILE="${home}/.config/firejail/agent-aws-creds.profile"
          fi
          exec systemd-run --user --scope --collect --quiet \
            -p "MemoryMax=$MEM" -p MemorySwapMax=0 -- \
            "$FIREJAIL" --quiet \
            --profile="$DEFAULT_PROFILE" \
            --whitelist="${home}/.nix-profile" \
            --whitelist="${home}/.local/state/nix" \
            --whitelist="${home}/.npm" \
            "''${AGENT_DIRS[@]}" \
            "''${AWS_FJ[@]}" \
            --oom=900 \
            --private-cwd="$PROJECT" --whitelist="$PROJECT" \
            env "''${AWS_ENV[@]}" "$@"
          ;;
        docker)
          # Host agents (pi/claude/…) are host Nix/npm binaries, so the
          # container needs the host /nix store + ~/.npm + PATH to run them.
          # Mount them read-only (best-effort). For a self-contained
          # container command, this is harmless overhead.
          exec docker run --rm -it \
            --network host --memory "$MEM" \
            -v /nix:/nix:ro \
            -v "${home}/.npm":"${home}/.npm":ro \
            -v "${home}/.config/litellm/keys":"${home}/.config/litellm/keys":ro \
            -v "$PROJECT":"$PROJECT":rw \
            -w "$PROJECT" \
            -e HOME="${home}" \
            -e PATH="$PATH" \
            "${cfg.dockerImage}" "$@"
          ;;
        vm)
          # Strongest tier: boot the prebuilt agent-vm guest in QEMU (via its
          # NixOS `vm` runner, which sets up the host /nix/store overlay + net
          # correctly). The guest is a clean rootfs (no host $HOME/secrets).
          # We add the CURRENT project (rw) + a command dir (ro) as extra 9p
          # shares via QEMU_OPTS; slirp user-net lets the guest reach the host
          # LiteLLM gateway at 10.0.2.2:4000. The guest runs /cmd/run, powers off.
          RUNNER="${cfg.guestToplevel}"
          if [ -z "$RUNNER" ] || [ ! -x "$RUNNER/bin/run-agent-vm-vm" ]; then
            echo "agent-sandbox: vm guest runner not built. Build it once with:" >&2
            echo "  nix build ~/ws/nix-config#nixosConfigurations.agent-vm.config.system.build.vm" >&2
            echo "  (it's normally prebuilt via the flake default). Use --tier firejail meanwhile." >&2
            exit 3
          fi
          CMDDIR=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/agent-vm-cmd.XXXXXX")
          trap 'rm -rf "$CMDDIR"' EXIT
          MEMMB=$(( $(mem_bytes "$MEM") / 1024 / 1024 ))
          [ "$MEMMB" -ge 512 ] || MEMMB=4096
          echo "agent-sandbox: booting agent-vm (QEMU, ''${MEMMB}M)… gateway at 10.0.2.2:4000" >&2
          # Project is shared via the runner's built-in 'shared' 9p
          # (SHARED_DIR -> guest /tmp/shared, symlinked to /project). The
          # command is appended to the kernel cmdline via the runner's
          # supported QEMU_KERNEL_PARAMS (agentcmd=<base64>) — this appends,
          # so it doesn't clobber the boot params. -m overrides guest default.
          CMD_B64=$(printf '%s ' "$@" | base64 -w0)
          export SHARED_DIR="$PROJECT"
          export QEMU_KERNEL_PARAMS="agentcmd=$CMD_B64"
          export QEMU_OPTS="-m $MEMMB"
          exec "$RUNNER/bin/run-agent-vm-vm"
          ;;
        ec2)
          # Ephemeral EC2 dev box: launch (or reuse) a tagged NixOS instance,
          # bidirectionally sync $PROJECT there with unison, SSH in and run
          # the command, sync back, and leave the instance stopped (cheap,
          # reconnect later) or terminate it. State lives entirely in AWS
          # tags (Name=asx-<workspace>) -- no local state file, so any host
          # with the numa AWS profile + your SSH key can reconnect to the
          # SAME workspace. Verbs (first positional arg): up, connect
          # (default if the workspace exists), down, status.
          #
          # Why plain AWS CLI instead of Terraform/terranix: terranix compiles
          # Nix to Terraform JSON and is the right tool for a FLEET of
          # declarative infra, but brings state-file/backend/locking
          # machinery that's overkill for one throwaway box discovered by a
          # tag. aws ec2 describe-instances IS the state store here.
          REGION="${cfg.ec2.region}"
          VOLSIZE="${toString cfg.ec2.volumeSizeGb}"
          AWS_PROFILE_EC2="${cfg.ec2.awsProfile}"
          KEYNAME="agent-sandbox-ec2"
          SGNAME="agent-sandbox-ec2"
          export AWS_PROFILE="$AWS_PROFILE_EC2"

          # --arch (default x86_64) selects the instance family, AMI arch,
          # and which arch's pkgs the gburd-provisioning config template is
          # built against (see mkEc2ConfigTemplate/pkgsFor above -- an
          # x86_64-built template embeds x86_64 store paths that can't run
          # on an arm64 box). --instance-type overrides the arch's default
          # entirely, for anyone who wants a specific size/family. Both are
          # parsed in the verb/workspace loop below (with everything else).
          ARCH="x86_64"
          ITYPE=""

          # Remember the workspace name used for THIS project directory, so
          # 'down'/'status' with no explicit workspace find the SAME
          # instance 'connect' created -- even if connect was given an
          # explicit name (e.g. a session id) that doesn't match
          # basename($PWD). Keyed by the project path (pi's own session-dir
          # convention: '/' -> '-'), not by workspace name, since that's
          # the one thing that's stable across a connect/down pair. This is
          # LOCAL-only convenience -- AWS tags remain the real state; a
          # missing/stale cache file just falls back to the old default.
          WSCACHE_DIR="${home}/.cache/agent-sandbox/workspaces"
          WSCACHE_KEY=$(printf '%s' "$PROJECT" | tr '/' '-')
          WSCACHE_FILE="$WSCACHE_DIR/--$WSCACHE_KEY--"

          # agent-sandbox --tier ec2 <verb> [workspace] [--terminate] [-- cmd...]
          #   verb defaults to 'connect'; workspace defaults to the cached
          #   name for this project dir, else $(basename $PROJECT).
          #   --terminate (down only): destroy the instance instead of stopping it.
          #   Everything after a literal -- is the remote command (connect only).
          VERB="connect"
          WORKSPACE=""
          TERMINATE=0
          case "''${1:-}" in up|connect|down|status) VERB="$1"; shift ;; esac
          while [ $# -gt 0 ] && [ "$1" != "--" ]; do
            case "$1" in
              --terminate) TERMINATE=1 ;;
              --arch) ARCH="$2"; shift ;;
              --instance-type) ITYPE="$2"; shift ;;
              *) WORKSPACE="$1" ;;
            esac
            shift
          done
          [ $# -gt 0 ] && [ "$1" = "--" ] && shift
          ${lib.optionalString (!cfg.ec2.buildAarch64) ''
            if [ "$ARCH" = "aarch64" ]; then
              echo "agent-sandbox: --arch aarch64 is unavailable on this host (programs.ai.sandbox.ec2.buildAarch64 = false -- no local/remote aarch64 builder configured here)" >&2
              exit 2
            fi
          ''}
          case "$ARCH" in
            x86_64) NIXARCH="x86_64-linux"; AWSARCH="x86_64" ;;
            aarch64|arm64) ARCH="aarch64"; NIXARCH="aarch64-linux"; AWSARCH="arm64" ;;
            *) echo "agent-sandbox: --arch must be x86_64 or aarch64 (got '$ARCH')" >&2; exit 2 ;;
          esac
          if [ -z "$ITYPE" ]; then
            case "$ARCH" in
              x86_64) ITYPE="${cfg.ec2.instanceTypeX86}" ;;
              aarch64) ITYPE="${cfg.ec2.instanceTypeArm}" ;;
            esac
          fi
          if [ -z "$WORKSPACE" ]; then
            if [ -r "$WSCACHE_FILE" ]; then
              WORKSPACE=$(cat "$WSCACHE_FILE")
            else
              WORKSPACE="$(basename "$PROJECT")"
            fi
          fi
          TAGNAME="asx-$WORKSPACE"
          KEYFILE="${home}/.ssh/$KEYNAME.pem"
          REMOTE_CMD=("$@")

          # Project lands at the SAME path relative to $HOME on the box as
          # it has locally (e.g. ~/ws/postgres/bcs here -> ~/ws/postgres/bcs
          # there), not a fixed 'project' dir -- so relative paths, direnv,
          # anything path-sensitive behaves the same on both sides. Falls
          # back to 'project' only if $PWD isn't under $HOME at all.
          case "$PROJECT" in
            "${home}"/*) REMOTE_REL="''${PROJECT#"${home}"/}" ;;
            *) REMOTE_REL="project" ;;
          esac

          # A tmux session PERSISTS on the box across ssh disconnects (the
          # agent keeps running if the connection drops) and lets a LATER
          # 'connect' to the same workspace re-attach to the exact same
          # session instead of starting a new one -- named after the
          # workspace, so it's stable across reconnects. tmux's -s allows
          # most characters but not ':' or '.'; sanitize defensively.
          TMUX_SESSION=$(printf '%s' "$WORKSPACE" | tr -c 'A-Za-z0-9_-' '-')

          # If $PROJECT is a git WORKTREE (e.g. ~/ws/postgres/bcs, where the
          # real repo data lives in ~/ws/postgres/.git/worktrees/bcs, itself
          # inside the BARE ~/ws/postgres/.git), only syncing $PROJECT
          # leaves git broken on the box: .git there is a one-line pointer
          # file to a path that doesn't exist remotely. Two strategies:
          #   1. FAST PATH: worktree on a real branch with a remote
          #      upstream -- the box does its OWN shallow clone of just
          #      that branch (GIT_WORKTREE_URL/GIT_WORKTREE_BRANCH below).
          #      Verified live: 33MB for a --depth 50 single-branch clone
          #      vs. 9.4GB for syncing the WHOLE local bare repo (every
          #      branch, every worktree) for ONE worktree's fixup -- a
          #      285x difference that turned a normal connect into a
          #      15+ minute hang.
          #   2. FALLBACK (detached HEAD, or a branch with no upstream --
          #      local-only commits a shallow clone from the remote can
          #      never reconstruct; confirmed live, GitHub's upload-pack
          #      refuses to fetch an arbitrary SHA not at a ref tip): the
          #      original sync-the-whole-common-dir approach, unchanged.
          GIT_COMMON_DIR=""
          GIT_WORKTREE_URL=""
          GIT_WORKTREE_BRANCH=""
          if command -v git >/dev/null 2>&1 && git -C "$PROJECT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            GCD=$(git -C "$PROJECT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
            case "$GCD" in
              "$PROJECT"/.git|"$PROJECT") ;; # inside $PROJECT already -- unison syncs it as part of the project
              "${home}"/*)
                GIT_COMMON_DIR="$GCD"
                BRANCH=$(git -C "$PROJECT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
                UPSTREAM=$(git -C "$PROJECT" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
                if [ -n "$BRANCH" ] && [ "$BRANCH" != "HEAD" ] && [ -n "$UPSTREAM" ]; then
                  REMOTE_NAME="''${UPSTREAM%%/*}"
                  URL=$(git -C "$PROJECT" remote get-url "$REMOTE_NAME" 2>/dev/null || true)
                  if [ -n "$URL" ]; then
                    GIT_WORKTREE_URL="$URL"
                    GIT_WORKTREE_BRANCH="$BRANCH"
                    GIT_COMMON_DIR="" # fast path applies -- skip the fallback entirely
                  fi
                fi
                ;;
            esac
          fi
          # Whatever workspace we ended up using, remember it -- so a LATER
          # 'down'/'status' with no argument finds this same instance.
          mkdir -p "$WSCACHE_DIR"
          printf '%s' "$WORKSPACE" > "$WSCACHE_FILE"

          aws_find_instance() {
            aws ec2 describe-instances --region "$REGION" \
              --filters "Name=tag:Name,Values=$TAGNAME" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
              --query 'Reservations[].Instances[0].[InstanceId,State.Name,PublicIpAddress]' \
              --output text 2>/dev/null | head -1
          }

          ensure_keypair_and_sg() {
            if ! aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEYNAME" >/dev/null 2>&1; then
              echo "agent-sandbox: creating EC2 key pair $KEYNAME..." >&2
              aws ec2 create-key-pair --region "$REGION" --key-name "$KEYNAME" \
                --query 'KeyMaterial' --output text > "$KEYFILE"
              chmod 600 "$KEYFILE"
            fi
            MYIP=$(curl -s https://checkip.amazonaws.com)
            if ! aws ec2 describe-security-groups --region "$REGION" --group-names "$SGNAME" >/dev/null 2>&1; then
              echo "agent-sandbox: creating security group $SGNAME (SSH from your current IP)..." >&2
              VPCID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
              GID=$(aws ec2 create-security-group --region "$REGION" --group-name "$SGNAME" \
                --description "agent-sandbox ec2 tier: SSH only" --vpc-id "$VPCID" --query 'GroupId' --output text)
              aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$GID" \
                --protocol tcp --port 22 --cidr "$MYIP/32" >/dev/null
            else
              # SG already exists -- but its ingress rule is a ONE-TIME
              # snapshot of whatever IP was current when it was FIRST
              # created. A home/mobile ISP's IP changes (DHCP renewal,
              # reconnect, etc.) -- confirmed live: this is exactly what
              # silently broke reconnecting to an already-running instance
              # the next day (AWS's own instance-status checks reported
              # fully healthy; ssh just timed out at the network level,
              # because the SG was still only authorizing YESTERDAY's IP).
              # Revoke every existing port-22 rule and reauthorize the
              # CURRENT IP -- unconditional and idempotent (revoking a rule
              # that doesn't match anything, or authorizing one that's
              # already there, are both harmless no-ops), so this never
              # accumulates stale rules release over release either.
              GID=$(aws ec2 describe-security-groups --region "$REGION" --group-names "$SGNAME" --query 'SecurityGroups[0].GroupId' --output text)
              OLD_CIDRS=$(aws ec2 describe-security-groups --region "$REGION" --group-ids "$GID" \
                --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`].IpRanges[].CidrIp' --output text 2>/dev/null || true)
              for cidr in $OLD_CIDRS; do
                [ "$cidr" = "$MYIP/32" ] && continue
                aws ec2 revoke-security-group-ingress --region "$REGION" --group-id "$GID" \
                  --protocol tcp --port 22 --cidr "$cidr" >/dev/null 2>&1 || true
              done
              aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$GID" \
                --protocol tcp --port 22 --cidr "$MYIP/32" >/dev/null 2>&1 || true
            fi
          }

          # SSH as root, once, to provision the gburd user + passwordless
          # sudo + flakes. This has to be a real NixOS config change (not a
          # bare useradd/sudoers.d drop-in): NixOS generates /etc/sudoers
          # from security.sudo.extraRules and does NOT include
          # /etc/sudoers.d/* (unlike Debian/Fedora) -- a dropped-in sudoers
          # file is silently ignored. Idempotent: skips straight past if
          # the user already exists (e.g. reconnecting to a stopped/
          # restarted instance).
          ssh_root() {
            IP="$1"; shift
            ssh -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -i "$KEYFILE" "root@$IP" "$@"
          }
          ssh_gburd() {
            IP="$1"; shift
            # -A: forward THIS host's ssh-agent. Needed by more than just
            # the final interactive session -- fixup_git_worktree's git
            # clone (from a private git@github.com:... remote) and
            # sync_git_identity's signing both need to authenticate AS the
            # user, and neither happens over the interactive -A tunnel
            # (that's only set up for the final `ssh -t -A -R` call).
            # Confirmed live: without -A here, fixup_git_worktree's clone
            # failed outright ("Could not read from remote repository").
            # Never a copied private key -- same forward-only posture as
            # every other credential in this tier (Bedrock bearer token,
            # LiteLLM keys, git signing key).
            ssh -A -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -i "$KEYFILE" "gburd@$IP" "$@"
          }

          # Run a slow, normally-noisy command quietly: one line while it
          # runs, full output only on failure. AGENT_SANDBOX_VERBOSE=1
          # always shows full output (debugging).
          run_quiet() {
            MSG="$1"; shift
            RUN_QUIET_LOG=$(mktemp)
            if [ -n "''${AGENT_SANDBOX_VERBOSE:-}" ]; then
              echo "agent-sandbox: $MSG..." >&2
              "$@" 2>&1 | tee "$RUN_QUIET_LOG" >&2
              STATUS="''${PIPESTATUS[0]}"
            else
              ( "$@" > "$RUN_QUIET_LOG" 2>&1 ) &
              QPID=$!
              if [ -t 2 ]; then
                SPIN='-\|/'
                I=0
                while kill -0 "$QPID" 2>/dev/null; do
                  printf '\ragent-sandbox: %s... %s' "$MSG" "''${SPIN:$((I++ % 4)):1}" >&2
                  sleep 0.15
                done
              else
                echo "agent-sandbox: $MSG... (please be patient)" >&2
              fi
              wait "$QPID"
              STATUS=$?
              if [ -t 2 ]; then
                printf '\r%80s\r' "" >&2
              fi
              if [ "$STATUS" -eq 0 ]; then
                echo "agent-sandbox: $MSG... done" >&2
              else
                echo "agent-sandbox: $MSG... FAILED" >&2
                cat "$RUN_QUIET_LOG" >&2
              fi
            fi
            return "$STATUS"
          }

          provision_gburd_user() {
            IP="$1"
            if ssh_root "$IP" 'id gburd >/dev/null 2>&1' 2>/dev/null; then
              return 0
            fi
            echo "agent-sandbox: provisioning gburd user + passwordless sudo on $TAGNAME (one-time)..." >&2
            AUTHKEY=$(cat "${home}/.ssh/id_auth_ed25519.pub" 2>/dev/null || cat "${home}/.ssh/id_ed25519.pub")
            case "$ARCH" in
              x86_64) TEMPLATE="${ec2ConfigTemplateX86}" ;;
              ${lib.optionalString cfg.ec2.buildAarch64 ''aarch64) TEMPLATE="${ec2ConfigTemplateArm}" ;;''}
            esac
            # Tailscale join is opt-in: only substituted in when a real key
            # is actually configured (${home}/.config/agent-sandbox/tailscale.key,
            # the sops-deployed dedicated agent-sandbox key -- see
            # floki.nix). No key -> tailscale-join.service is left in the
            # generated config but with an empty auth-key, which `tailscale
            # up` rejects harmlessly (the service fails, nothing else on
            # the box depends on it, ssh/agents/everything else works
            # exactly as before this feature existed).
            TSKEY=$(cat "${home}/.config/agent-sandbox/tailscale.key" 2>/dev/null || true)
            TSHOSTNAME=$(printf '%s' "$TAGNAME" | tr -c 'A-Za-z0-9-' '-')
            sed -e "s|@AUTHKEY@|$AUTHKEY|" -e "s|@TSKEY@|$TSKEY|" -e "s|@TSHOSTNAME@|$TSHOSTNAME|" "$TEMPLATE" | \
              ssh_root "$IP" 'cat > /etc/nixos/configuration.nix'
            run_quiet "one-time NixOS provisioning on $TAGNAME" ssh_root "$IP" 'nixos-rebuild switch'
            rm -f "$RUN_QUIET_LOG"
          }

          # Push THIS connecting host's git-signing PUBLIC key into the
          # box's gitconfig (never a private key -- see the -A ssh-agent
          # forward in 'connect' below, which is what actually signs).
          # Dynamic per connecting host, not baked into ec2.nix: floki/meh/
          # arnold each rotate their OWN distinct signing key
          # (ssh-management/signing.nix), so there's no single static key
          # that would be correct here. git's gpg.format=ssh + a literal
          # user.signingKey string writes that string to a temp file and
          # invokes 'ssh-keygen -Y sign -f <tempfile>' itself, which
          # resolves the private half via the FORWARDED agent (confirmed
          # via GIT_TRACE=1) -- so only the public key string needs to land
          # in gitconfig, no .pub file to deploy separately.
          sync_git_identity() {
            IP="$1"
            SIGNPUB="${home}/.ssh/id_signing_ed25519.pub"
            [ -r "$SIGNPUB" ] || return 0
            if [ -z "''${SSH_AUTH_SOCK:-}" ]; then
              echo "agent-sandbox: warning: no local ssh-agent (SSH_AUTH_SOCK unset) -- git signing on $TAGNAME will fail without one." >&2
            fi
            SIGNKEY=$(cat "$SIGNPUB")
            # --local (in $REMOTE_REL), NOT --global: the box's global
            # ~/.config/git/config is a home-manager-owned symlink into the
            # read-only /nix/store (programs.git.enable=true, shared by
            # every host via cli/git.nix) -- `git config --global` there
            # fails outright ("could not lock config file ... Read-only
            # file system", confirmed live). A per-repo --local config is
            # a normal mutable file regardless of what owns the global
            # one, and this is only ever signing commits in THIS one
            # project anyway. Must run AFTER sync_unison/fixup_git_worktree
            # (the connect call site does) -- $REMOTE_REL doesn't exist on
            # the box until then.
            ssh_gburd "$IP" "git -C '$REMOTE_REL' config --local gpg.format ssh && \
              git -C '$REMOTE_REL' config --local user.signingKey '$SIGNKEY' && \
              git -C '$REMOTE_REL' config --local commit.gpgsign true && \
              git -C '$REMOTE_REL' config --local tag.gpgsign true" 2>&1 | tail -5 || true
          }

          # Optional: --aws-profile <name> (parsed in the shared outer flag
          # loop above, already used by firejail's --whitelist=~/.aws) also
          # applies to the ec2 tier: push just that ONE profile's creds to
          # the box + export AWS_PROFILE there, so an agent running INSIDE
          # the sandbox (e.g. pi following the aws-benchmark skill to launch
          # its own throwaway EC2 instances for a numa clock-sweep) has
          # something to authenticate with. Confirmed live gap: a sandboxed
          # agent that correctly followed the aws-benchmark skill still had
          # no ~/.aws at all on the box -- this tier never synced it,
          # unlike firejail's --aws-profile which whitelists the real
          # ~/.aws read-only. Scoped to the ONE named profile (not the
          # whole ~/.aws, which may hold other unrelated accounts) via
          # `aws configure export-credentials`, which resolves whatever
          # auth type that profile actually uses (static keys here, but
          # also correct for SSO/role-assumption profiles) into plain
          # access-key/secret -- avoids depending on SSO token caches or
          # role-assumption chains existing on the box, which they won't.
          sync_aws_credentials() {
            IP="$1"
            [ -n "$AWS_PROFILE_NAME" ] || return 0
            CREDS=$(aws configure export-credentials --profile "$AWS_PROFILE_NAME" 2>/dev/null) || {
              echo "agent-sandbox: warning: --aws-profile $AWS_PROFILE_NAME has no exportable credentials locally, skipping" >&2
              return 0
            }
            AKID=$(printf '%s' "$CREDS" | jq -r '.AccessKeyId')
            SECRET=$(printf '%s' "$CREDS" | jq -r '.SecretAccessKey')
            SESSTOK=$(printf '%s' "$CREDS" | jq -r '.SessionToken // ""')
            REGION_LOCAL=$(aws configure get region --profile "$AWS_PROFILE_NAME" 2>/dev/null || echo "$REGION")
            ssh_gburd "$IP" 'mkdir -p .aws && chmod 700 .aws'
            {
              echo "[$AWS_PROFILE_NAME]"
              echo "aws_access_key_id = $AKID"
              echo "aws_secret_access_key = $SECRET"
              [ -n "$SESSTOK" ] && echo "aws_session_token = $SESSTOK"
              true
            } | ssh_gburd "$IP" 'cat > .aws/credentials && chmod 600 .aws/credentials'
            {
              echo "[profile $AWS_PROFILE_NAME]"
              echo "region = $REGION_LOCAL"
              echo "output = json"
            } | ssh_gburd "$IP" 'cat > .aws/config && chmod 600 .aws/config'
          }

          # Keep a STABLE ssh alias (asx-<workspace>) pointed at whatever IP
          # the box currently has -- EC2 gives it a fresh public IP on every
          # start, so "ssh <the box>" would otherwise mean re-discovering
          # the IP by hand every time. This is what makes
          # `code --remote ssh-remote+asx-<workspace> ~/ws/...` or Zed's
          # ssh_connections (host: asx-<workspace>) work without babysitting
          # -- point either editor's remote-SSH feature at the alias, not a
          # raw IP. Lives in ~/.ssh/agent-sandbox-ec2.conf, Include'd from
          # the main config (cli/ssh.nix) -- NOT written into
          # ~/.ssh/config directly, since home-manager owns that whole
          # file and would clobber a runtime-written block on the next
          # switch. One Host block per workspace, replaced wholesale each
          # call (simplest correct way to "update in place" in a flat file).
          ALIASFILE="${home}/.ssh/agent-sandbox-ec2.conf"
          remove_ssh_alias_block() {
            [ -f "$ALIASFILE" ] || return 0
            TMPFILE=$(mktemp)
            awk -v tag="$TAGNAME" '
              $0 == "Host " tag { skip=1 }
              skip && $0 == "" { skip=0; next }
              !skip { print }
            ' "$ALIASFILE" > "$TMPFILE"
            mv "$TMPFILE" "$ALIASFILE"
          }
          sync_ssh_alias() {
            IP="$1"
            remove_ssh_alias_block
            {
              cat "$ALIASFILE" 2>/dev/null || true
              printf 'Host %s\n' "$TAGNAME"
              printf '  HostName %s\n' "$IP"
              printf '  User gburd\n'
              printf '  IdentityFile %s\n' "$KEYFILE"
              printf '  IdentitiesOnly yes\n'
              printf '  StrictHostKeyChecking accept-new\n'
              printf '  ForwardAgent yes\n\n'
            } > "$ALIASFILE.new"
            mv "$ALIASFILE.new" "$ALIASFILE"
            echo "agent-sandbox: ssh alias '$TAGNAME' -> $IP (ssh $TAGNAME / code --remote ssh-remote+$TAGNAME / Zed ssh_connections)" >&2
          }

          # Deploy this flake's console/ai (agents + LiteLLM client config)
          # as the gburd user via standalone home-manager. Pulls from
          # GitHub over the instance's own (unrestricted outbound) network
          # access -- no need to push the flake source itself over unison.
          deploy_home_manager() {
            IP="$1"
            # activationPackage's default output IS the built generation --
            # running its own ./activate script performs the switch. (No
            # 'switch' subcommand: that belongs to the home-manager CLI,
            # not to a prebuilt generation invoked directly -- confirmed
            # live: 'nix run ...activationPackage -- switch' fails with
            # "unknown option 'switch'".) --refresh: always deploy whatever
            # is CURRENTLY pushed, never a cached-stale flake read.
            run_quiet "deploying home-manager (gburd@ec2) on $TAGNAME" ssh_gburd "$IP" \
              'nix --extra-experimental-features "nix-command flakes" build --refresh --no-link --print-out-paths github:gburd/nix-config#homeConfigurations."gburd@ec2".activationPackage 2>&1' || true
            GENPATH=$(tail -1 "$RUN_QUIET_LOG")
            rm -f "$RUN_QUIET_LOG"
            case "$GENPATH" in
              /nix/store/*) ;;
              *) echo "agent-sandbox: home-manager build failed on $TAGNAME (see above); continuing without it." >&2; return 1 ;;
            esac
            run_quiet "activating home-manager generation on $TAGNAME" ssh_gburd "$IP" "$GENPATH/activate" || true
            rm -f "$RUN_QUIET_LOG"
          }

          latest_nixos_ami() {
            aws ec2 describe-images --region "$REGION" --owners 427812963091 \
              --filters "Name=name,Values=nixos/25.11*-$NIXARCH" "Name=architecture,Values=$AWSARCH" \
              --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text
          }

          up_instance() {
            EXISTING=$(aws_find_instance)
            if [ -n "$EXISTING" ]; then
              ID=$(echo "$EXISTING" | cut -f1)
              STATE=$(echo "$EXISTING" | cut -f2)
              if [ "$STATE" = "stopped" ]; then
                echo "agent-sandbox: starting existing instance $ID ($TAGNAME)..." >&2
                aws ec2 start-instances --region "$REGION" --instance-ids "$ID" >/dev/null
              else
                echo "agent-sandbox: $TAGNAME already $STATE ($ID)" >&2
              fi
              return
            fi
            ensure_keypair_and_sg
            AMI=$(latest_nixos_ami)
            SGID=$(aws ec2 describe-security-groups --region "$REGION" --group-names "$SGNAME" --query 'SecurityGroups[0].GroupId' --output text)
            echo "agent-sandbox: launching $ITYPE ($AMI) as $TAGNAME..." >&2
            aws ec2 run-instances --region "$REGION" \
              --image-id "$AMI" --instance-type "$ITYPE" \
              --key-name "$KEYNAME" --security-group-ids "$SGID" \
              --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":$VOLSIZE,\"VolumeType\":\"gp3\"}}]" \
              --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAGNAME}]" \
              --query 'Instances[0].InstanceId' --output text >/dev/null
          }

          wait_for_ssh() {
            echo -n "agent-sandbox: waiting for $TAGNAME to be reachable..." >&2
            for _ in $(seq 1 60); do
              IP=$(aws_find_instance | cut -f3)
              if [ -n "$IP" ] && [ "$IP" != "None" ] && \
                 ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 \
                     -o IdentitiesOnly=yes -i "$KEYFILE" "root@$IP" true 2>/dev/null; then
                echo " up ($IP)" >&2
                echo "$IP"
                return 0
              fi
              echo -n "." >&2
              sleep 5
            done
            echo " TIMED OUT" >&2
            return 1
          }

          # Make sure gburd + home-manager (the agents + LiteLLM client
          # config) are in place before anything logs in as gburd. Cheap
          # no-op on a reconnect (both checks are idempotent).
          ensure_provisioned() {
            IP="$1"
            provision_gburd_user "$IP"
            deploy_home_manager "$IP"
          }

          ensure_remote_unison() {
            IP="$1"
            ssh_gburd "$IP" 'command -v unison >/dev/null 2>&1' 2>/dev/null && return 0
            run_quiet "installing unison on $TAGNAME (one-time)" ssh_gburd "$IP" \
              'nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#unison' || true
            rm -f "$RUN_QUIET_LOG"
          }

          sync_unison() {
            IP="$1"; DIR="$2"
            ssh_gburd "$IP" "mkdir -p '$DIR'" 2>/dev/null || true
            ensure_remote_unison "$IP"
            run_quiet "syncing $WORKSPACE <-> $TAGNAME" unison "$PROJECT" "ssh://gburd@$IP/$DIR" \
              -sshargs "-i $KEYFILE -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes" \
              -prefer newer -batch -silent -ui text -contactquietly -ignore 'Name .direnv' || true
            rm -f "$RUN_QUIET_LOG"
          }

          # For a git WORKTREE, $PROJECT/.git is just a one-line pointer
          # file -- the real repo data (refs, index, HEAD, and the shared
          # object store) lives in GIT_COMMON_DIR, OUTSIDE $PROJECT (e.g.
          # ~/ws/postgres/.git for a ~/ws/postgres/bcs worktree). Synced
          # separately, at the SAME path relative to $HOME on both sides,
          # so the pointer file (synced as part of $PROJECT above) resolves
          # correctly and git commands work on the box.
          sync_git_common_dir() {
            IP="$1"
            [ -n "$GIT_COMMON_DIR" ] || return 0
            GCD_REL="''${GIT_COMMON_DIR#"${home}"/}"
            ssh_gburd "$IP" "mkdir -p '$(dirname "$GCD_REL")'" 2>/dev/null || true
            run_quiet "syncing git data ($GIT_COMMON_DIR, this can be large)" unison "$GIT_COMMON_DIR" "ssh://gburd@$IP/$GCD_REL" \
              -sshargs "-i $KEYFILE -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes" \
              -prefer newer -batch -silent -ui text -contactquietly || true
            rm -f "$RUN_QUIET_LOG"
          }

          # Fast path: the box does its OWN shallow clone of just
          # GIT_WORKTREE_BRANCH from GIT_WORKTREE_URL. $PROJECT's regular
          # files (already synced by sync_unison, including any local
          # uncommitted edits) get overlaid on top of the clone's checkout
          # -- git only compares the working tree against its own
          # index/HEAD, so this is fully correct regardless of how the
          # files arrived. Idempotent: skips straight past if .git is
          # already a real directory (a reconnect to an already-fixed-up box).
          fixup_git_worktree() {
            IP="$1"
            [ -n "$GIT_WORKTREE_URL" ] || return 0
            run_quiet "cloning $GIT_WORKTREE_BRANCH on $TAGNAME" ssh_gburd "$IP" "set -eu
              cd '$REMOTE_REL'
              [ -d .git ] && exit 0
              TMPCLONE=\$(mktemp -d)
              git clone --quiet --depth 50 --branch '$GIT_WORKTREE_BRANCH' --single-branch '$GIT_WORKTREE_URL' \"\$TMPCLONE\"
              find . -maxdepth 1 -name .git -type f -delete
              mv \"\$TMPCLONE/.git\" ./.git
              find \"\$TMPCLONE\" -maxdepth 2 -delete 2>/dev/null || true
              git checkout --quiet -- . 2>/dev/null || true
            " || true
            rm -f "$RUN_QUIET_LOG"
          }

          # Sync ONLY the session-storage root of the agent actually being
          # started (not all agents' session state, not the rest of
          # $HOME) -- e.g. running 'pi' syncs ~/.pi/agent/sessions both
          # ways, so a session started locally can be resumed on the box
          # (pi --session-id <id> / -r / -c: all keyed by session id, not
          # by cwd, so this works even though the EC2 project path differs
          # from the local one). Also syncs that agent's LiteLLM virtual
          # key, since the EC2 home-manager deploy has litellm.enable =
          # false (no local gateway there) and never generates one.
          agentSessionDir() {
            case "$1" in
              pi)     echo ".pi/agent/sessions" ;;
              claude) echo ".claude/projects" ;;
              codex)  echo ".codex/sessions" ;;
              maki)   echo ".maki/sessions" ;;
              hermes) echo ".hermes/sessions" ;;
              *)      echo "" ;;
            esac
          }

          # Mangled per-project session-subdir name, matching each
          # agent's OWN convention -- computed from $PROJECT (the box's
          # absolute path is $HOME/$REMOTE_REL, which equals $PROJECT
          # exactly whenever REMOTE_REL isn't the "project" fallback, i.e.
          # in the common case of a project actually under $HOME). Used to
          # scope pi/claude's sync to just THIS project's session data via
          # unison's -path, instead of their entire (potentially huge --
          # confirmed live: 675MB pi, 4.1GB claude, across every project
          # ever worked on) sessions root. codex/maki/hermes have no such
          # per-project subdir at all (confirmed: codex organizes by date,
          # maki/hermes are flat UUID/timestamp files) -- nothing to scope
          # to, so they still sync in full (small in practice: <500MB).
          projectSessionSubdir() {
            case "$1" in
              pi)     printf '%s' "''${PROJECT#/}" | tr '/' '-' | sed 's/^/--/; s/$/--/' ;;
              claude) printf '%s' "$PROJECT" | tr '/' '-' ;;
              *)      echo "" ;;
            esac
          }

          sync_agent_state() {
            IP="$1"; AGENT="$2"
            SESSDIR=$(agentSessionDir "$AGENT")
            KEYSRC="${home}/.config/litellm/keys/$AGENT.key"
            if [ -n "$SESSDIR" ]; then
              ssh_gburd "$IP" "mkdir -p '$SESSDIR'" 2>/dev/null || true
              UNISON_ARGS=("${home}/$SESSDIR" "ssh://gburd@$IP/$SESSDIR" \
                -sshargs "-i $KEYFILE -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes" \
                -prefer newer -batch -silent -ui text -contactquietly)
              SUBDIR=$(projectSessionSubdir "$AGENT")
              [ -n "$SUBDIR" ] && UNISON_ARGS+=(-path "$SUBDIR")
              run_quiet "syncing $AGENT session state" unison "''${UNISON_ARGS[@]}" || true
              rm -f "$RUN_QUIET_LOG"
            fi
            if [ -r "$KEYSRC" ]; then
              ssh_gburd "$IP" 'mkdir -p .config/litellm/keys' 2>/dev/null || true
              scp -q -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -i "$KEYFILE" \
                "$KEYSRC" "gburd@$IP:.config/litellm/keys/$AGENT.key" 2>/dev/null || true
            fi
          }

          # Sync EVERY known agent's session state, not just the one named
          # after '--' on the command line. connect with no '-- cmd' drops
          # into an interactive shell (bash -l) and the user picks an agent
          # once inside tmux -- REMOTE_CMD is empty in that case, so the
          # single-agent sync above never ran at all. Confirmed live: a
          # session run entirely by typing 'pi' inside the interactive
          # shell never made it back to the local ~/.pi/agent/sessions,
          # because nothing ever called sync_agent_state for it. Cheap
          # (session dirs are small, unlike the git-object-store mistake
          # this tier already learned from) -- always sync all of them.
          sync_all_agent_state() {
            IP="$1"
            for a in pi claude codex maki hermes; do
              sync_agent_state "$IP" "$a"
            done
          }

          case "$VERB" in
            up)
              ensure_keypair_and_sg
              up_instance
              IP=$(wait_for_ssh)
              ensure_provisioned "$IP"
              sync_ssh_alias "$IP"
              echo "agent-sandbox: $TAGNAME is up. 'agent-sandbox --tier ec2 connect $WORKSPACE' to sync + SSH in." >&2
              ;;
            status)
              EXISTING=$(aws_find_instance)
              if [ -z "$EXISTING" ]; then
                echo "agent-sandbox: no instance tagged $TAGNAME" >&2; exit 1
              fi
              echo "$EXISTING" | awk -F'\t' '{print "instance="$1, "state="$2, "ip="$3}'
              ;;
            down)
              ensure_keypair_and_sg
              EXISTING=$(aws_find_instance)
              if [ -z "$EXISTING" ]; then
                echo "agent-sandbox: no instance tagged $TAGNAME" >&2; exit 1
              fi
              ID=$(echo "$EXISTING" | cut -f1)
              IP=$(echo "$EXISTING" | cut -f3)
              if [ -n "$IP" ] && [ "$IP" != "None" ]; then
                echo "agent-sandbox: syncing $WORKSPACE back before shutdown..." >&2
                sync_unison "$IP" "$REMOTE_REL" || true
                sync_git_common_dir "$IP" || true
              fi
              # Sync failures above must NEVER block the stop/terminate
              # below -- a stuck/slow sync (e.g. unison's first-ever
              # dependency fetch on a fresh box) must not leave an
              # instance running (and billing) indefinitely just because
              # this script never reached the actual shutdown call.
              MODE="stop"
              [ "$TERMINATE" -eq 1 ] && MODE="terminate"
              if [ "$MODE" = "terminate" ]; then
                echo "agent-sandbox: TERMINATING $TAGNAME ($ID) -- EBS volume is gone after this." >&2
                aws ec2 terminate-instances --region "$REGION" --instance-ids "$ID" >/dev/null
                rm -f "$WSCACHE_FILE"
                remove_ssh_alias_block
              else
                echo "agent-sandbox: stopping $TAGNAME ($ID) -- reconnect later with 'up'/'connect', EBS persists." >&2
                aws ec2 stop-instances --region "$REGION" --instance-ids "$ID" >/dev/null
              fi
              ;;
            connect)
              # Always refresh the SG's SSH rule for whatever IP THIS host
              # currently has, even when reconnecting to an
              # already-running instance -- confirmed live: a changed
              # public IP (ISP DHCP renewal overnight) silently breaks
              # reconnecting to a box left running from a prior session.
              # AWS's own instance-status checks report fully healthy;
              # ssh just times out at the network level, because the SG
              # was still only authorizing the OLD IP. Idempotent/cheap
              # when nothing's actually changed.
              ensure_keypair_and_sg
              EXISTING=$(aws_find_instance)
              if [ -z "$EXISTING" ]; then
                up_instance
              elif [ "$(echo "$EXISTING" | cut -f2)" = "stopped" ]; then
                up_instance
              fi
              IP=$(wait_for_ssh)
              ensure_provisioned "$IP"
              sync_ssh_alias "$IP"
              echo "agent-sandbox: syncing $WORKSPACE -> $TAGNAME ($IP)..." >&2
              sync_unison "$IP" "$REMOTE_REL"
              fixup_git_worktree "$IP"
              sync_git_common_dir "$IP"
              sync_git_identity "$IP"
              sync_aws_credentials "$IP"
              # Sync every agent's session state + LiteLLM key BEFORE
              # connecting -- 'connect' with no '-- cmd' drops into an
              # interactive shell and the agent is picked once inside
              # tmux, so there's no command-line hint of which one; syncing
              # all of them up front means whichever one gets typed
              # already has its prior local session state + key in place.
              sync_all_agent_state "$IP"
              echo "agent-sandbox: connecting (tmux session '$TMUX_SESSION', persists across disconnects). Ctrl-D/exit to disconnect; syncs back after." >&2
              # Wrapped in tmux new-session -A (attach-or-create): the
              # session survives an ssh drop, and reconnecting later re-
              # attaches to the SAME session (same running agent, same
              # scrollback) instead of starting a new one. Built as one
              # shell-quoted argv (printf '%q') for the same reason as
              # REMOTE_LINE below: ssh sends whatever we pass as ONE string
              # to the remote shell, so anything with embedded spaces must
              # already be correctly quoted before it gets there.
              if [ ''${#REMOTE_CMD[@]} -eq 0 ]; then
                TMUX_CMD=(bash -l)
              else
                TMUX_CMD=("''${REMOTE_CMD[@]}")
              fi
              # -e AWS_PROFILE=...: only takes effect when tmux actually
              # creates a NEW session (harmless no-op on -A reattach to an
              # existing one, same as everything else here being safe to
              # rerun) -- lets an agent inside follow the aws-benchmark
              # skill against the SAME profile sync_aws_credentials just
              # pushed, without needing --aws-profile passed again by hand.
              TMUX_ENV=()
              [ -n "$AWS_PROFILE_NAME" ] && TMUX_ENV=(-e "AWS_PROFILE=$AWS_PROFILE_NAME")
              REMOTE_LINE=$(printf '%q ' tmux new-session -A -s "$TMUX_SESSION" -c "$REMOTE_REL" "''${TMUX_ENV[@]}" "''${TMUX_CMD[@]}")
              # -A: forward THIS host's ssh-agent, so git commit/tag signing
              # on the box resolves the private key via the agent (never a
              # copied key file -- sync_git_identity above only pushed the
              # PUBLIC key string into gitconfig). -R forwards THIS host's
              # loopback LiteLLM gateway to the EC2 box's own 127.0.0.1:4000
              # -- agents there talk to "127.0.0.1:4000" exactly like they
              # do locally, no idea they're actually tunneling over SSH. The
              # gateway itself is still loopback-only everywhere; this is
              # the same "reach it through a controlled channel, never
              # expose it to the internet" posture as every other tier.
              ssh -t -A -R "4000:127.0.0.1:${toString config.programs.ai.litellm.port}" \
                -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -i "$KEYFILE" "gburd@$IP" \
                "exec $REMOTE_LINE" || true
              echo "agent-sandbox: syncing $WORKSPACE <- $TAGNAME ($IP)..." >&2
              sync_unison "$IP" "$REMOTE_REL"
              sync_git_common_dir "$IP"
              sync_all_agent_state "$IP"
              ;;
            *) echo "agent-sandbox: unknown ec2 verb '$VERB' (up|connect|down|status)" >&2; exit 2 ;;
          esac
          ;;
        *) echo "agent-sandbox: unknown tier '$TIER' (firejail|docker|vm|ec2)" >&2; exit 2 ;;
      esac
    '';
  };

  # Shell completion (fish: the interactive shell here).
  fishCompletion = pkgs.writeText "agent-sandbox.fish" ''
    complete -c agent-sandbox -f
    complete -c agent-sandbox -l tier -x -a "firejail docker vm ec2" -d "isolation tier"
    complete -c agent-sandbox -l mem -x -d "memory cap e.g. 8G"
    complete -c agent-sandbox -l aws -d "direct-AWS netns (breaks gateway agents)"
    complete -c agent-sandbox -l ssh -d "forward ssh-agent socket (SSH out; keys stay blocked)"
    complete -c agent-sandbox -s h -l help -d "show help"
    complete -c agent-sandbox -n "not __fish_seen_subcommand_from --tier --mem" \
      -a "pi claude codex maki hermes kiro gnhf bash" -d "command to sandbox"
  '';
in
{
  options.programs.ai.sandbox = {
    enable = mkEnableOption "agent-sandbox: run agents isolated (firejail/docker/vm)";
    defaultMemMax = mkOption {
      type = types.str;
      default = "12G";
      description = "Default memory cap for the sandbox (a real cgroup, systemd-run -p MemoryMax=; a runaway is also OOM-first).";
    };
    dockerImage = mkOption {
      type = types.str;
      default = "nixos/nix:latest";
      description = "Base image for the docker tier.";
    };
    awsNetDevice = mkOption {
      type = types.str;
      default = "";
      description = ''
        Optional fallback uplink for the --aws private netns. The launcher
        auto-detects the default-route device; set this only if that fails
        on a given host.
      '';
    };
    guestToplevel = mkOption {
      type = types.str;
      default =
        let vm = inputs.self.nixosConfigurations.agent-vm or null;
        in if vm == null then "" else "${vm.config.system.build.vm}";
      description = ''
        Store path of the built agent-vm QEMU runner
        (nixosConfigurations.agent-vm.config.system.build.vm), used by the
        vm tier. Defaults to the flake's agent-vm output. Empty =>
        vm tier errors with build instructions.
      '';
    };
    ec2 = {
      region = mkOption {
        type = types.str;
        default = "us-east-1";
        description = "AWS region for the ec2 tier's instances.";
      };
      instanceTypeX86 = mkOption {
        type = types.str;
        default = "m6id.8xlarge";
        description = ''
          Default x86_64 EC2 instance type for the ec2 tier. Must be an
          instance-store ("d" suffix) family -- the tier mounts local NVMe
          at /mnt/nvme and relocates $HOME/ws + Nix's build-dir onto it,
          skipping the slow EBS root entirely for project/build I/O.
          m6id.8xlarge: 32 vCPU / 128 GiB RAM / 1900 GB NVMe.
        '';
      };
      instanceTypeArm = mkOption {
        type = types.str;
        default = "m7gd.8xlarge";
        description = ''
          Default aarch64 (Graviton) EC2 instance type for the ec2 tier,
          used when --arch aarch64 is passed. Same instance-store
          requirement as instanceTypeX86. m7gd.8xlarge: 32 vCPU / 128 GiB
          RAM / 1900 GB NVMe.
        '';
      };
      buildAarch64 = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether this HOST can build the aarch64 EC2 config template
          (mkEc2ConfigTemplate's Arm variant). The generated template's
          own store-path references (pkgs.git etc.) must be built for
          aarch64-linux -- on NixOS this needs
          boot.binfmt.emulatedSystems to include aarch64-linux (see
          nixos/_mixins/workstations/common.nix); on non-NixOS hosts
          (e.g. arnold, Fedora) there's no equivalent, and no local/remote
          aarch64 builder means --arch aarch64 can never succeed there.
          Set false on such hosts so home-manager switch doesn't try to
          build the aarch64 template at all -- confirmed live: it failed
          outright ("required system: aarch64-linux... current system:
          x86_64-linux") on arnold, blocking every switch, including ones
          with unrelated changes. x86_64 sandboxes (the default arch)
          remain fully unaffected either way.
        '';
      };
      volumeSizeGb = mkOption {
        type = types.int;
        default = 60;
        description = ''
          Root EBS volume size (GB) for the ec2 tier's instances. This is
          OS + the FULL Nix store (all 6 agents, their runtimes, neovim +
          plugins, zed-editor, cargo/rustc for from-source builds like
          maki/terax-ai, etc.) -- measured at ~15GB for just the built
          home-manager closure, before build-time scratch/GC headroom, so
          20GB (this option's old default) reliably ran out of space
          mid-deploy on a fresh instance. Project/build DATA still lives
          on the instance's local NVMe, not here (see
          instanceTypeX86/instanceTypeArm) -- this is Nix-store headroom,
          not workload storage.
        '';
      };
      awsProfile = mkOption {
        type = types.str;
        default = "numa";
        description = "AWS CLI profile the ec2 tier uses (see programs.ai.sandbox --aws-profile).";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ agent-sandbox ];
    home.file = {
      ".config/firejail/agent.profile".source = agentProfile;
      ".config/firejail/agent-aws.profile".source = agentAwsProfile;
      ".config/firejail/agent-aws-creds.profile".source = agentCredsProfile;
      ".config/firejail/agent-ssh.profile".source = agentSshProfile;
      ".config/fish/completions/agent-sandbox.fish".source = fishCompletion;
    };
  };
}
