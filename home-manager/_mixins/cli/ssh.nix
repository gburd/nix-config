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
    includes = [ "~/.ssh/agent-sandbox-ec2.conf" ];
    matchBlocks = {
      meh = lib.hm.dag.entryBefore [ "net" ] {
        host = "meh";
        hostname = "192.168.1.185";
        forwardAgent = true;
        extraOptions = {
          StreamLocalBindUnlink = "yes";
        };
        remoteForwards = [
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
      santorini = lib.hm.dag.entryBefore [ "net" ] {
        host = "win santorini";
        hostname = "santorini";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
          RemoteCommand = "powershell -NoProfile";
        };
      };
      # wix — same Windows host, but log straight into the NixOS-WSL distro as gburd.
      wix = lib.hm.dag.entryBefore [ "net" ] {
        host = "wix";
        hostname = "santorini";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
          RemoteCommand = "wsl.exe -d NixOS --user gburd";
        };
      };
      # PostgreSQL build-farm animal hosts (not NixOS, so not covered by `net`).
      # Force publickey auth with our standard key and disable the password
      # fallback so a missing/empty agent fails loudly instead of silently
      # prompting for a password. forwardAgent lets the inner `ssh pgbf@host`
      # hop reuse the (now non-empty) agent.
      buildfarm = lib.hm.dag.entryBefore [ "net" ] {
        host = "sun rv";
        forwardAgent = true;
        identitiesOnly = true;
        identityFile = "~/.ssh/id_ed25519";
        extraOptions = {
          PreferredAuthentications = "publickey";
        };
      };
      net = {
        host = builtins.concatStringsSep " " hostnames;
        forwardAgent = true;
        remoteForwards = [{
          bind.address = ''/%d/.gnupg-sockets/S.gpg-agent'';
          host.address = ''/%d/.gnupg-sockets/S.gpg-agent.extra'';
        }];
      };
      trusted = lib.hm.dag.entryBefore [ "net" ] {
        host = "burd.me *.burd.me *.ts.burd.me";
        forwardAgent = true;
      };
    };
  };
}
