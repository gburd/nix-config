{ config, lib, ... }:
{
  users.users.root = {
    # Root's INITIAL password hash comes from sops (nixos/_mixins/
    # secrets.yaml, key "root-password"), not a plaintext-committed hash.
    # The previous committed $6$ hash was offline-crackable AND was shared
    # verbatim with the installer "nixos" user, so cracking one yielded
    # both — that hash is now gone from the repo entirely.
    #
    # NOTE on semantics: with mutableUsers=true (our default),
    # hashedPasswordFile only seeds root's password on a FRESH install;
    # on an already-provisioned host an existing /etc/shadow entry is
    # preserved (so `passwd` changes stick). Either way no secret lives
    # in the Nix store / git. neededForUsers makes sops decrypt it early
    # enough for first-boot user creation.
    hashedPasswordFile = config.sops.secrets.root-password.path;
    openssh.authorizedKeys.keys = [ ];
  };

  sops.secrets.root-password = {
    sopsFile = ../../secrets.yaml;
    neededForUsers = true;
  };

  # Root has no SSH login (wheel + sudo is the admin path); the password
  # is for local/console/recovery (single-user mode) only.
  services.openssh.settings.PermitRootLogin = lib.mkDefault "no";
}
