{ config, desktop, lib, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    fuse-overlayfs
  ] ++ lib.optionals (desktop != null) [
    unstable.quickemu
    unstable.quickgui
    xorg.xhost
  ];

  virtualisation = {
    containers.enable = true;
    containers.storage.settings = {
      storage = {
        driver = "overlay";
        runroot = "/run/containers/storage";
        graphroot = "/var/lib/containers/storage";
        rootless_storage_path = "/tmp/containers-$USER";
        options.overlay.mountopt = "nodev,metacopy=on,acltype=posixacl";
      };
    };
    docker.storageDriver = "btrfs";
  };

}
