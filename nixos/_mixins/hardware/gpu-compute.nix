{ pkgs, ... }:
# GPU compute support for headless hosts. Enables the OpenGL / Vulkan /
# OpenCL userspace stack so AMD / Intel / NVIDIA GPUs are available for
# workloads like Ollama (Vulkan via RADV), llama.cpp, OpenCL kernels,
# video transcode, etc., **without** requiring an X server or Wayland
# compositor.
#
# Intended for hosts where `desktop = null` is passed to `mkHost`
# (so `nixos/_mixins/desktop/default.nix` is NOT imported), but we still
# need hardware acceleration. Kernel-side amdgpu / i915 / nvidia modules
# still come from kernel defaults + per-host hardware files +
# `nixos-hardware`; this module ships the userspace bits on top.
{
  hardware.graphics = {
    enable = true;
    # 32-bit support (mesa.lib32) for occasional 32-bit OpenCL ICDs and
    # for tools like Steam-on-headless / wine; harmless if unused.
    enable32Bit = true;
    extraPackages = with pkgs; [
      # Mesa 3D incl. RADV (Vulkan) — already pulled by hardware.graphics
      # but listed explicitly so it's obvious.
      mesa
      # OpenCL ICD loader (lets clinfo / OpenCL apps discover devices)
      ocl-icd
      # Mesa's RustICD (rusticl) provides OpenCL on AMD via Mesa, which
      # works on GCN 1.0 (e.g. meh's FirePro D700s) where ROCm doesn't.
      mesa.opencl
      # Intel media driver — useful when Intel iGPU is also present
      intel-media-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  # CLI helpers for diagnosing GPU compute paths from a tty:
  #   vulkaninfo --summary, clinfo, glxinfo (needs X but ships info bin),
  #   radeontop, intel-gpu-tools, nvidia-smi (when NVIDIA), nvtop.
  environment.systemPackages = with pkgs; [
    vulkan-tools
    clinfo
    mesa-demos
    radeontop
    nvtopPackages.full
  ];
}
