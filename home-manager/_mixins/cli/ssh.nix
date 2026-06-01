{ outputs, lib, ... }:
let
  hostnames = builtins.attrNames outputs.nixosConfigurations;
in
{
  programs.ssh = {
    enable = true;
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
