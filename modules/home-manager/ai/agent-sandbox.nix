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
    blacklist ${home}/.aws
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

  # Default: no SSH at all — block the entire ~/.ssh dir (private keys +
  # config + known_hosts) AND the ssh-agent socket (which lives outside
  # ~/.ssh, under /run/user/<uid>). Without blocking the socket, an agent
  # could still use your loaded keys via SSH_AUTH_SOCK. --ssh re-enables it.
  commonProfile = ''
    ${commonBase}
    blacklist ${home}/.ssh
    blacklist /run/user/*/gcr/ssh
    blacklist /run/user/*/keyring/ssh
    blacklist /run/user/*/ssh-agent*
    rmenv SSH_AUTH_SOCK
  '';

  # --ssh variant: allow SSH via the forwarded ssh-agent SOCKET only. Block
  # every PRIVATE KEY file individually (so a rogue agent still can't read/
  # exfiltrate key material), but leave ~/.ssh/config (host aliases) and
  # known_hosts readable and let the agent socket do the actual auth. The
  # launcher binds $SSH_AUTH_SOCK and keeps the SSH_AUTH_SOCK env var.
  sshProfile = ''
    ${commonBase}
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
    agent-sandbox — run a command isolated (firejail/docker/vm).

    USAGE:
      agent-sandbox [OPTIONS] <cmd> [args...]
      agent-sandbox [OPTIONS] -- <cmd> [args...]

    OPTIONS:
      --tier <t>   firejail (default) | docker | vm
      --mem <size> memory cap, e.g. 8G / 512M (default: ${cfg.defaultMemMax})
      --aws        DIRECT-AWS mode: private netns + DNS/HTTPS-only egress.
                   BREAKS gateway-routed agents (pi/claude/codex/maki/hermes)
                   because the host LiteLLM gateway is unreachable in a private
                   netns. Use only for tools hitting AWS with their own creds.
      --ssh        Allow outbound SSH: forwards the ssh-agent SOCKET into the
                   sandbox so the agent can SSH to LAN hosts / EC2 / etc. using
                   your loaded keys. Private key FILES stay blocked (the agent
                   signs challenges; keys can't be read/exfiltrated). Requires
                   a running ssh-agent with keys loaded (ssh-add -l). Connect
                   by full hostname / Tailscale name (~/.ssh/config aliases
                   aren't available in the sandbox); use
                   StrictHostKeyChecking=accept-new on first connect.
      -h, --help   this help.

    EXAMPLES:
      agent-sandbox pi                 # isolate pi (recommended: firejail)
      agent-sandbox --mem 8G claude    # cap memory
      agent-sandbox -- bash            # inspect the sandbox interactively
      agent-sandbox --tier docker mycmd
      agent-sandbox --ssh claude       # allow SSH out (agent socket, not keys)

    ISOLATION (firejail tier): cwd is read-write; ~/.ssh, ~/.aws, the Bedrock
    bearer token, sops secrets, password-store and other ~/ws projects are
    blocked; the agent reaches AWS only through the loopback LiteLLM gateway.
    A runaway is memory-capped (--mem) and killed first by the OOM killer, so
    it dies in the sandbox instead of taking down your terminals.
  '';

  gatewayRouted = "pi claude codex maki hermes kiro";

  agent-sandbox = pkgs.writeShellApplication {
    name = "agent-sandbox";
    # firejail must be the SUID wrapper at /run/wrappers/bin/firejail
    # (programs.firejail.enable), NOT the non-SUID nixpkgs store binary.
    runtimeInputs = [ pkgs.coreutils pkgs.docker_29 pkgs.iproute2 pkgs.iptables pkgs.qemu_kvm ];
    text = ''
      set -euo pipefail
      # Preserve the CALLER's PATH: writeShellApplication resets PATH to its
      # runtimeInputs, which drops ~/.nix-profile/bin (where the agent
      # wrappers live) and ~/.pi/agent/bin etc. Capture it before use.
      CALLER_PATH="''${PATH}"
      TIER=firejail
      MEM="${cfg.defaultMemMax}"
      AWS=0
      SSH=0
      while [ $# -gt 0 ]; do
        case "$1" in
          -h|--help) printf '%s' ${lib.escapeShellArg usage}; exit 0 ;;
          --tier) TIER="$2"; shift 2 ;;
          --mem)  MEM="$2"; shift 2 ;;
          --aws)  AWS=1; shift ;;
          --ssh)  SSH=1; shift ;;
          --)     shift; break ;;
          -*)     echo "agent-sandbox: unknown flag $1 (try --help)" >&2; exit 2 ;;
          *)      break ;;
        esac
      done
      [ $# -gt 0 ] || { printf '%s' ${lib.escapeShellArg usage} >&2; exit 2; }

      PROJECT="$PWD"

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
            exec "$FIREJAIL" --quiet \
              --profile="${home}/.config/firejail/agent-aws.profile" \
              --net="$NETDEV" \
              --whitelist="${home}/.nix-profile" \
              --whitelist="${home}/.local/state/nix" \
              --whitelist="${home}/.npm" \
              --whitelist="${home}/.pi" \
              --rlimit-as="$(mem_bytes "$MEM")" --oom=900 \
              --private-cwd="$PROJECT" --whitelist="$PROJECT" \
              env PATH="$CALLER_PATH" "$@"
          fi
          # Default: share host /nix + network; isolate the filesystem + cap
          # memory. --rlimit-as caps RAM; --oom=900 makes a runaway the OOM
          # killer's first victim so it dies here, not taking down terminals.
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
            exec "$FIREJAIL" --quiet \
              --profile="${home}/.config/firejail/agent-ssh.profile" \
              --whitelist="${home}/.nix-profile" \
              --whitelist="${home}/.local/state/nix" \
              --whitelist="${home}/.npm" \
              --whitelist="${home}/.pi" \
              --whitelist="$SOCK" \
              --rlimit-as="$(mem_bytes "$MEM")" --oom=900 \
              --private-cwd="$PROJECT" --whitelist="$PROJECT" \
              env PATH="$CALLER_PATH" SSH_AUTH_SOCK="$SOCK" "$@"
          fi
          exec "$FIREJAIL" --quiet \
            --profile="${home}/.config/firejail/agent.profile" \
            --whitelist="${home}/.nix-profile" \
            --whitelist="${home}/.local/state/nix" \
            --whitelist="${home}/.npm" \
            --whitelist="${home}/.pi" \
            --rlimit-as="$(mem_bytes "$MEM")" --oom=900 \
            --private-cwd="$PROJECT" --whitelist="$PROJECT" \
            env PATH="$CALLER_PATH" "$@"
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
        *) echo "agent-sandbox: unknown tier '$TIER' (firejail|docker|vm)" >&2; exit 2 ;;
      esac
    '';
  };

  # Shell completion (fish: the interactive shell here).
  fishCompletion = pkgs.writeText "agent-sandbox.fish" ''
    complete -c agent-sandbox -f
    complete -c agent-sandbox -l tier -x -a "firejail docker vm" -d "isolation tier"
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
      description = "Default memory cap for the sandbox (firejail --rlimit-as; a runaway is also OOM-first).";
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
  };

  config = mkIf cfg.enable {
    home.packages = [ agent-sandbox ];
    home.file = {
      ".config/firejail/agent.profile".source = agentProfile;
      ".config/firejail/agent-aws.profile".source = agentAwsProfile;
      ".config/firejail/agent-ssh.profile".source = agentSshProfile;
      ".config/fish/completions/agent-sandbox.fish".source = fishCompletion;
    };
  };
}
