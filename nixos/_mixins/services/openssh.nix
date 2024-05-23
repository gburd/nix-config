{ lib, config, ... }:
let
  # Sops needs acess to the keys before the persist dirs are even mounted; so
  # just persisting the keys won't work, we must point at /persist
  hasOptinPersistence = config.environment.persistence ? "/persist";
in
{
  services = {
    openssh = {
      enable = true;
      settings = {
        # Harden
        PasswordAuthentication = false;
        PermitRootLogin = lib.mkDefault "no";
        # Automatically remove stale sockets
        StreamLocalBindUnlink = "yes";
        # Allow forwarding ports to everywhere
        GatewayPorts = "clientspecified";
      };
      hostKeys = [{
        path = "${lib.optionalString hasOptinPersistence "/persist"}/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }];
    };
    sshguard = {
      enable = true;
      whitelist = [
        # TODO
        "192.168.40.0/24"
        "10.0.0.0/8"
        "100.0.0.0/8"
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  # Passwordless sudo when SSH'ing with keys
  security.pam.enableSSHAgentAuth = true;
}
