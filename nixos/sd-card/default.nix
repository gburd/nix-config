{ ... }: {
  nixpkgs.hostPlatform.system = "aarch64-linux";
  nixpkgs.buildPlatform.system = "x86_64-linux";

  imports = [
    <nixpkgs/nixos/modules/installer/sd-card/sd-image-aarch64.nix>
  ];

  systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDPvS6pE5Y8Yc3YnKpKinjVKyziqnb7JZJGonDKnZi3I Greg Burd <gburd@symas.com> - 2023-08-03"
    ];
  };

  system.stateVersion = "23.11";
}
