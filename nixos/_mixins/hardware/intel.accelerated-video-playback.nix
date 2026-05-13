{ pkgs, ... }:
{
  # Intel Arc Xe2 (Lunar Lake) uses iHD (intel-media-driver) for VA-API.
  # intel-compute-runtime provides OpenCL/Level Zero for GPU compute.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      libva-vdpau-driver
      libvdpau-va-gl
      intel-compute-runtime
    ];
  };
  environment.sessionVariables = { LIBVA_DRIVER_NAME = "iHD"; };
}
