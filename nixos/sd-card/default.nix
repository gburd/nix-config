{ ... }: {
  nixpkgs.hostPlatform.system = "aarch64-linux";
  nixpkgs.buildPlatform.system = "x86_64-linux";

  imports = [
    <nixpkgs/nixos/modules/installer/sd-card/sd-image-aarch64.nix>
  ];

  systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
  users.users.root = {
    openssh.authorizedKeys.keys = [
      # Use personal key only, not work keys
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGSNy/vMr2Zk9pvfjQnxiU9F8CGQJ wCiXDxPecKG9/q+ Greg Burd <greg@burd.me> - 2023-01-23"
    ];
  };

  system.stateVersion = "25.05";
}
