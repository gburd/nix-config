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
