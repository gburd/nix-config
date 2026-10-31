{ outputs, lib, ... }:
let
  hostnames = builtins.attrNames outputs.nixosConfigurations;
in
{
  programs.ssh = {
    enable = true;
    # agent-sandbox's ec2 tier writes/updates per-workspace Host entries
    # here at runtime (IP changes every launch, so it can't be a
    # declarative matchBlock rebuilt only on switch) -- lets VSCode's
    # Remote-SSH / Zed's ssh_connections / a plain `ssh asx-<workspace>`
    # all use a STABLE name instead of chasing a fresh IP by hand. `!`
    # sources it as an absolute path outside $HOME/.ssh's usual relative
    # includes; touch once so a fresh host has an empty-but-valid file
    # before agent-sandbox ever runs (ssh errors on a missing Include).
    # ~/.ssh/ec2/*.conf: per-project EC2 hosts that test harnesses write at
    # runtime (e.g. ~/ws/dbsql's dbsql-kiwi.conf). They were being added by
    # hand-editing ~/.ssh/config, which turned home-manager's symlink into a
    # plain file and blocked the next switch ("would be clobbered"). A glob
    # Include with no matches is not an error, so this is safe on hosts with
    # no ~/.ssh/ec2.
    includes = [ "~/.ssh/agent-sandbox-ec2.conf" "~/.ssh/ec2/*.conf" ];
    # 26.05: programs.ssh.matchBlocks -> programs.ssh.settings. The block key
    # IS the Host pattern (multi-word patterns use a literal "Host ..." key),
    # and fields use upstream OpenSSH directive names (HostName, User,
    # ForwardAgent, IdentityFile, IdentitiesOnly, RequestTTY, RemoteCommand,
    # ...) directly -- the old `extraOptions` nesting is gone (those were
    # already OpenSSH directives, so they merge in flat). DAG ordering
    # (lib.hm.dag.entryBefore) is unchanged.
    settings = {
      meh = lib.hm.dag.entryBefore [ "net" ] {
        HostName = "192.168.1.185";
        ForwardAgent = true;
        # meh needs its identity PINNED, unlike the other LAN hosts. The
        # agent here holds ~95 keys (1Password plus the signing keys) and
        # sshd disconnects after ~6 failed offers with "Too many
        # authentication failures", so `ssh meh` died with exit 255 before
        # ever reaching the key that works -- while `ping` succeeded. That
        # read as "meh is offline" for much of one session; it was not.
        # IdentitiesOnly + IdentityAgent=none offers exactly one key.
        IdentitiesOnly = true;
        IdentityAgent = "none";
        IdentityFile = "~/.ssh/id_ed25519";
        PreferredAuthentications = "publickey";
        StreamLocalBindUnlink = "yes";
        RemoteForward = [
          {
            bind.address = ''/%d/.gnupg-sockets/S.gpg-agent'';
            host.address = ''/%d/.gnupg-sockets/S.gpg-agent.extra'';
          }
          # NOTE: 1Password agent socket forwarding removed - now using standard ssh-agent
        ];
      };
      # santorini (Windows) — reachable as both "win" and "santorini".
      # Drop into a PowerShell session on login instead of the default cmd.exe.
      # (RemoteCommand needs RequestTTY; to run a one-off command or scp, override
      #  with `ssh -o RemoteCommand=none -o RequestTTY=no santorini ...`.)
      "Host win santorini" = lib.hm.dag.entryBefore [ "net" ] {
        # By its Headscale MagicDNS name. Windows Firewall allows sshd only
        # on the Private profile. santorini's Wi-Fi ("sedgwick") is Public,
        # its Tailscale adapter is Private, so sshd is reachable over the
        # tailnet and NOT over the LAN (192.168.1.158:22 drops). A bare
        # "santorini" resolved through the OLD tailnet's MagicDNS to a dead
        # 100.x address once santorini moved to Headscale.
        HostName = "santorini.ts.burd.me";
        # santorini's Windows sshd authorizes ONLY id_ed25519 (m19Q...). The
        # "Host *" default offers id_auth_ed25519, which it rejects. That
        # worked only while id_ed25519 also sat in the ssh-agent. When the
        # agent died (gcr child OOM-killed), santorini started saying
        # "Permission denied". Pin the key FILE so login no longer depends
        # on agent state. Verified 2026-10-14: m19Q is accepted; yaU3 (auth)
        # and H31v (signing) are not.
        IdentityFile = "~/.ssh/id_ed25519";
        ForwardAgent = true;
        RequestTTY = "yes";
        RemoteCommand = "powershell -NoProfile";
      };
      # wixa: the NixOS-WSL distro on santorini (Windows NixOS, aarch64), its
      # OWN tailnet node with its
      # own sshd (100.64.0.3). It used to be reached by ssh-ing to Windows and
      # running `wsl.exe -d NixOS`, which needs Windows' sshd, a TTY and a
      # RemoteCommand, so `ssh wixa <cmd>` failed with "Cannot execute
      # command-line and remote command". Direct now. A Windows scheduled
      # task (wix-keepalive, runs as gburd at boot) keeps the distro
      # running, so wixa stays on the tailnet with nobody logged in.
      wixa = lib.hm.dag.entryBefore [ "net" ] {
        HostName = "wixa.ts.burd.me";
        IdentityFile = "~/.ssh/id_ed25519";
        ForwardAgent = true;
      };
      # PostgreSQL build-farm animal hosts (not NixOS, so not covered by `net`).
      # Force publickey auth with our standard key and disable the password
      # fallback so a missing/empty agent fails loudly instead of silently
      # prompting for a password. ForwardAgent lets the inner `ssh pgbf@host`
      # hop reuse the (now non-empty) agent.
      "Host sun rv" = lib.hm.dag.entryBefore [ "net" ] {
        ForwardAgent = true;
        IdentitiesOnly = true;
        IdentityFile = "~/.ssh/id_ed25519";
        PreferredAuthentications = "publickey";
      };
      net = {
        header = "Host " + builtins.concatStringsSep " " hostnames;
        ForwardAgent = true;
        RemoteForward = [{
          bind.address = ''/%d/.gnupg-sockets/S.gpg-agent'';
          host.address = ''/%d/.gnupg-sockets/S.gpg-agent.extra'';
        }];
      };
      "Host burd.me *.burd.me *.ts.burd.me" = lib.hm.dag.entryBefore [ "net" ] {
        ForwardAgent = true;
      };
    };
  };
}
