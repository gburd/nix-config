{ lib, config, ... }:
{
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/bf75af76-49b0-41fa-a4e5-9a52a6a0a667";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/bf75af76-49b0-41fa-a4e5-9a52a6a0a667";
      fsType = "btrfs";
      options = [ "subvol=nix" "noatime" "compress=zstd" ];
    };

  fileSystems."/persist" =
    { device = "/dev/disk/by-uuid/bf75af76-49b0-41fa-a4e5-9a52a6a0a667";
      fsType = "btrfs";
      options = [ "subvol=persist" "noatime" "compression=zstd" ];
      neededForBoot = true;
    };

  fileSystems."/var/logs" =
    { device = "/dev/disk/by-uuid/bf75af76-49b0-41fa-a4e5-9a52a6a0a667";
      fsType = "btrfs";
      options = [ "subvol=logs" "noatime" "compress=zstd" ];
      neededForBoot = true;
    };

}
