{ lib, config, ... }:
{
  boot.initrd = {
    supportedFilesystems = [ "btrfs" ];
}
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/bf75af76-49b0-41fa-a4e5-9a52a6a0a667";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" ];
    };

  boot.initrd.luks.devices."enc".device = "/dev/disk/by-uuid/470152b6-16cc-4dcf-b1e9-c684c1589e33";

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/bf75af76-49b0-41fa-a4e5-9a52a6a0a667";
      fsType = "btrfs";
      options = [ "subvol=nix" "noatime" "compress=zstd" ];
    };

  fileSystems."/persist" =
    { device = "/dev/disk/by-uuid/bf75af76-49b0-41fa-a4e5-9a52a6a0a667";
      fsType = "btrfs";
      options = [ "subvol=persist" "noatime" "compression=zstd" ];
    };

  fileSystems."/var/logs" =
    { device = "/dev/disk/by-uuid/bf75af76-49b0-41fa-a4e5-9a52a6a0a667";
      fsType = "btrfs";
      options = [ "subvol=logs" "noatime" "compress=zstd" ];
      neededForBoot = true;
    };

  fileSystems."/swap" =
    { device = "/dev/disk/by-uuid/bf75af76-49b0-41fa-a4e5-9a52a6a0a667";
      fsType = "btrfs";
      options = [ "subvol=swap" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/3D04-3716";
      fsType = "vfat";
    };

  swapDevices = [ ];

}
