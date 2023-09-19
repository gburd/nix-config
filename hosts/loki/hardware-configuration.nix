{
  imports = [
    ../common/optional/encrypted-root.nix
  ];

  boot = {
    initrd = {
      availableKernelModules = [ "ahci" "xhci_pci" "nvme" "thunderbolt" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
      luks.devices."luks-fae33851-b8d8-430b-8c6a-cd18675b8252".device = "/dev/disk/by-uuid/fae33851-b8d8-430b-8c6a-cd18675b8252";
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
      };
      efi.canTouchEfiVariables = true;
    };
  };

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/88c63d59-2b86-4336-b8c7-1a4e6da1b443";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/2EF0-3AA5";
      fsType = "vfat";
    };

  swapDevices = [{
    device = "/dev/disk/by-uuid/e7cc3e9c-2acc-4bbd-bc2f-a67a08a94db7";
  }];

  nixpkgs.hostPlatform.system = "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = true;
  powerManagement.cpuFreqGovernor = "powersave";
}
