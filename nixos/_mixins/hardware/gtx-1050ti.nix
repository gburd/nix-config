{ pkgs, config, ... }:
let
  vulkanDriverFiles = [
    "${config.hardware.nvidia.package}/share/vulkan/icd.d/nvidia_icd.x86_64.json"
    "${config.hardware.nvidia.package.lib32}/share/vulkan/icd.d/nvidia_icd.i686.json"
  ];
in
{
  environment = {
    systemPackages = with pkgs; [ vulkan-tools nvtopPackages.full ];

    variables = {
      VK_DRIVER_FILES = builtins.concatStringsSep ":" vulkanDriverFiles;
    };
  };

  # Load NVIDIA driver for PRIME offload support
  # With PRIME offload, Intel will be primary but NVIDIA available on-demand
  # modesetting driver handles Intel GPU, listed first to make it primary
  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

  hardware = {
    nvidia = {
      # GTX 1050 Ti is Pascal generation, use stable driver
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      # Enable modesetting for proper Wayland support
      modesetting.enable = true;

      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      powerManagement.enable = false;

      # Fine-grained power management only works on Turing or newer GPUs.
      # GTX 1050 Ti is Pascal generation, so this must be false.
      powerManagement.finegrained = false;

      # Use the NVidia open source kernel module:
      # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
      # GTX 1050 Ti (Pascal/GP107) requires proprietary driver
      open = false;

      nvidiaSettings = true;
    };

    graphics = {
      enable = true;
      enable32Bit = true;
      # Include both NVIDIA and Intel Mesa drivers for PRIME offload
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
        libva-vdpau-driver
        libvdpau-va-gl
      ];
    };
  };

  services.pulseaudio.support32Bit = true;

  hardware.nvidia-container-toolkit.enable = true;
}
