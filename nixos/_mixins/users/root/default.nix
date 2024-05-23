{ lib, ... }:
{
  users.users.root = {
    # mkpasswd -m sha-512
    hashedPassword = "$6$Dq4WmzyLjQUTyXT1$0Ll5rZ0R33qfGnEmAOZQuh.6udRN19luImYAmqsCKxfV14yHQ8vt9B/pf945..r1jTmlu7wfAXSe7kfoBm9jK0";
    openssh.authorizedKeys.keys = [ ];
  };

  services.openssh.settings.PermitRootLogin = lib.mkDefault "no";
}
