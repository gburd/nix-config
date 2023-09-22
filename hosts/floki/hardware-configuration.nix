{
  imports = [
    ../common/optional/btrfs.nix
  ];

  boot = {
    initrd = {
      availableKernelModules = [ "ahci" "xhci_pci" "nvme" "thunderbolt" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
      kernelModules = [ "kvm-amd" ];
    };
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
      };
      efi.canTouchEfiVariables = true;
    };
  };
  
  boot.initrd.luks.devices."enc".device = "/dev/disk/by-uuid/470152b6-16cc-4dcf-b1e9-c684c1589e33";

  fileSystems."/swap" =
    { device = "/dev/disk/by-uuid/bf75af76-49b0-41fa-a4e5-9a52a6a0a667";
      fsType = "btrfs";
      options = [ "subvol=swap" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/3D04-3716";
      fsType = "vfat";
    };

  # fileSystems = {
  #   "/boot" = {
  #     device = "/dev/disk/by-label/ESP";
  #     fsType = "vfat";
  #   };
  # };

  swapDevices = [{
    device = "/swap/swapfile";
    size = 8196;
  }];

  nixpkgs.hostPlatform.system = "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = true;
  powerManagement.cpuFreqGovernor = "powersave";
}
