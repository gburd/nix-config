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
      agent-sandbox --tier ec2 [up|connect|down|status] [workspace] [--terminate] [-- cmd...]
      A real EC2 instance (NixOS AMI), not a local sandbox: the whole VM IS
      the isolation boundary. State lives in AWS instance tags
      (Name=agent-sandbox-<workspace>, default workspace = current dir
      name) so ANY host with the numa AWS profile + your SSH key can
      reconnect to the SAME box.
        up       launch (or start, if stopped) the workspace, wait for SSH.
        connect  (default) up + bidirectional unison sync + ssh in; syncs
                 back on disconnect. With a -- separator + a command, runs
                 that command instead of an interactive shell.
        down     sync back, then STOP the instance (EBS persists, cheap,
                 resume later). --terminate destroys it (EBS gone too).
        status   show instance id / state / IP for the workspace, if any.
      Config: programs.ai.sandbox.ec2.{region,instanceType,volumeSizeGb,awsProfile}.
      One-time on first up: creates a dedicated key pair + security group
      (SSH from your current IP only) via the configured AWS profile.

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
          # tags (Name=agent-sandbox-<workspace>) -- no local state file, so
          # any host with the numa AWS profile + your SSH key can reconnect
          # to the SAME workspace. Verbs (first positional arg): up, connect
          # (default if the workspace exists), down, status.
          #
          # Why plain AWS CLI instead of Terraform/terranix: terranix compiles
          # Nix to Terraform JSON and is the right tool for a FLEET of
          # declarative infra, but brings state-file/backend/locking
          # machinery that's overkill for one throwaway box discovered by a
          # tag. aws ec2 describe-instances IS the state store here.
          REGION="${cfg.ec2.region}"
          ITYPE="${cfg.ec2.instanceType}"
          VOLSIZE="${toString cfg.ec2.volumeSizeGb}"
          AWS_PROFILE_EC2="${cfg.ec2.awsProfile}"
          KEYNAME="agent-sandbox-ec2"
          SGNAME="agent-sandbox-ec2"
          export AWS_PROFILE="$AWS_PROFILE_EC2"

          # agent-sandbox --tier ec2 <verb> [workspace] [--terminate] [-- cmd...]
          #   verb defaults to 'connect'; workspace defaults to $(basename $PROJECT).
          #   --terminate (down only): destroy the instance instead of stopping it.
          #   Everything after a literal -- is the remote command (connect only).
          VERB="connect"
          WORKSPACE=""
          TERMINATE=0
          case "''${1:-}" in up|connect|down|status) VERB="$1"; shift ;; esac
          while [ $# -gt 0 ] && [ "$1" != "--" ]; do
            case "$1" in
              --terminate) TERMINATE=1 ;;
              *) WORKSPACE="$1" ;;
            esac
            shift
          done
          [ $# -gt 0 ] && [ "$1" = "--" ] && shift
          [ -z "$WORKSPACE" ] && WORKSPACE="$(basename "$PROJECT")"
          TAGNAME="agent-sandbox-$WORKSPACE"
          KEYFILE="${home}/.ssh/$KEYNAME.pem"
          REMOTE_CMD=("$@")

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
            if ! aws ec2 describe-security-groups --region "$REGION" --group-names "$SGNAME" >/dev/null 2>&1; then
              echo "agent-sandbox: creating security group $SGNAME (SSH from your current IP)..." >&2
              VPCID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
              GID=$(aws ec2 create-security-group --region "$REGION" --group-name "$SGNAME" \
                --description "agent-sandbox ec2 tier: SSH only" --vpc-id "$VPCID" --query 'GroupId' --output text)
              MYIP=$(curl -s https://checkip.amazonaws.com)
              aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$GID" \
                --protocol tcp --port 22 --cidr "$MYIP/32" >/dev/null
            fi
          }

          latest_nixos_ami() {
            aws ec2 describe-images --region "$REGION" --owners 427812963091 \
              --filters "Name=name,Values=nixos/25.11*-x86_64-linux" "Name=architecture,Values=x86_64" \
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

          ensure_remote_unison() {
            IP="$1"
            ssh -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -i "$KEYFILE" "root@$IP" \
              'command -v unison >/dev/null 2>&1' 2>/dev/null && return 0
            echo "agent-sandbox: installing unison on $TAGNAME (one-time)..." >&2
            ssh -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -i "$KEYFILE" "root@$IP" \
              'nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#unison' \
              2>&1 | tail -5 || true
          }

          sync_unison() {
            IP="$1"; DIR="$2"
            ssh -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -i "$KEYFILE" "root@$IP" \
              "mkdir -p '$DIR'" 2>/dev/null || true
            ensure_remote_unison "$IP"
            unison "$PROJECT" "ssh://root@$IP/$DIR" \
              -sshargs "-i $KEYFILE -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes" \
              -prefer newer -batch -ignore 'Name .direnv' -ignore 'Name .git' \
              2>&1 | tail -20 || true
          }

          case "$VERB" in
            up)
              up_instance
              wait_for_ssh >/dev/null
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
              EXISTING=$(aws_find_instance)
              if [ -z "$EXISTING" ]; then
                echo "agent-sandbox: no instance tagged $TAGNAME" >&2; exit 1
              fi
              ID=$(echo "$EXISTING" | cut -f1)
              IP=$(echo "$EXISTING" | cut -f3)
              if [ -n "$IP" ] && [ "$IP" != "None" ]; then
                echo "agent-sandbox: syncing $WORKSPACE back before shutdown..." >&2
                sync_unison "$IP" "/root/project"
              fi
              MODE="stop"
              [ "$TERMINATE" -eq 1 ] && MODE="terminate"
              if [ "$MODE" = "terminate" ]; then
                echo "agent-sandbox: TERMINATING $TAGNAME ($ID) -- EBS volume is gone after this." >&2
                aws ec2 terminate-instances --region "$REGION" --instance-ids "$ID" >/dev/null
              else
                echo "agent-sandbox: stopping $TAGNAME ($ID) -- reconnect later with 'up'/'connect', EBS persists." >&2
                aws ec2 stop-instances --region "$REGION" --instance-ids "$ID" >/dev/null
              fi
              ;;
            connect)
              EXISTING=$(aws_find_instance)
              if [ -z "$EXISTING" ]; then
                up_instance
              elif [ "$(echo "$EXISTING" | cut -f2)" = "stopped" ]; then
                up_instance
              fi
              IP=$(wait_for_ssh)
              echo "agent-sandbox: syncing $WORKSPACE -> $TAGNAME ($IP)..." >&2
              sync_unison "$IP" "/root/project"
              echo "agent-sandbox: connecting. Ctrl-D/exit to disconnect; syncs back after." >&2
              # ssh with MULTIPLE command-line arguments joins them with a
              # plain space and sends that as ONE string to the remote's
              # shell (no quoting at all) -- so an arg containing spaces
              # (e.g. bash -c "a b") gets silently re-split wrong on the far
              # end. Build ONE correctly shell-quoted string locally instead
              # and pass it as a single ssh argv element.
              if [ ''${#REMOTE_CMD[@]} -eq 0 ]; then
                REMOTE_LINE='exec "$SHELL" -l'
              else
                REMOTE_LINE=$(printf '%q ' "''${REMOTE_CMD[@]}")
                REMOTE_LINE="exec $REMOTE_LINE"
              fi
              ssh -t -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -i "$KEYFILE" "root@$IP" \
                "cd project && $REMOTE_LINE" || true
              echo "agent-sandbox: syncing $WORKSPACE <- $TAGNAME ($IP)..." >&2
              sync_unison "$IP" "/root/project"
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
      instanceType = mkOption {
        type = types.str;
        default = "c7i.xlarge";
        description = "Default EC2 instance type for the ec2 tier.";
      };
      volumeSizeGb = mkOption {
        type = types.int;
        default = 100;
        description = "Root EBS volume size (GB) for the ec2 tier's instances.";
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
