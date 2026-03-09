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

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    nvidia = {
      # RTX 3080 Ti is Ampere generation (GA102), use vulkan_beta for latest features
      package = config.boot.kernelPackages.nvidiaPackages.vulkan_beta;

      modesetting.enable = true;

      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      powerManagement.enable = false;

      # Fine-grained power management works on Ampere GPUs like RTX 3080 Ti.
      # Set to false by default for stability, enable if needed.
      powerManagement.finegrained = false;

      # Use the NVidia open source kernel module:
      # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
      # RTX 3080 Ti (Ampere/GA102) supports open source driver, but use proprietary for stability
      open = false;

      nvidiaSettings = true;
    };

    graphics = {
      enable = true;
      inherit (config.hardware.nvidia) package;
    };
  };

  services.pulseaudio.support32Bit = true;

  hardware.nvidia-container-toolkit.enable = true;
}
