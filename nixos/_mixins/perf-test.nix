# Perf-test tuning shared by the EC2 performance hosts (pgperf-arm / pgperf-x86).
# Bare-metal-style PostgreSQL benchmarking knobs. Conservative defaults; the
# per-host configs/agents tune sizes to the actual instance memory.
{ lib, pkgs, ... }:
{
  # --- kernel / sysctl tuning for large-shared-buffers DB benchmarking ---
  boot.kernel.sysctl = {
    # Allow large shared memory segments (PostgreSQL shared_buffers).
    "kernel.shmmax" = lib.mkDefault 137438953472; # 128 GiB ceiling
    "kernel.shmall" = lib.mkDefault 33554432; # in pages
    # VM tuning: don't swap eagerly, flush dirty pages steadily.
    "vm.swappiness" = lib.mkDefault 1;
    "vm.dirty_background_ratio" = lib.mkDefault 5;
    "vm.dirty_ratio" = lib.mkDefault 10;
    "vm.overcommit_memory" = lib.mkDefault 2;
    # Network: large buffers for high-throughput pgbench/HammerDB clients.
    "net.core.somaxconn" = lib.mkDefault 4096;
    "net.ipv4.tcp_max_syn_backlog" = lib.mkDefault 4096;
  };

  # HugePages help PostgreSQL with large shared_buffers (set the count
  # per-host to ~shared_buffers/2MiB). 0 here = opt-in per host.
  boot.kernelParams = [ "transparent_hugepage=never" ];

  # --- the benchmarking toolbox ---
  environment.systemPackages = with pkgs; [
    # PostgreSQL client + bench tools
    postgresql_17
    # load generators / profiling
    sysbench
    fio # storage benchmarking
    hyperfine
    perf
    flamegraph
    numactl # NUMA pinning for clock-sweep / buffer-manager tests
    htop
    btop
    iotop
    sysstat # sar/iostat/mpstat
    tmux
    git
    gnumake
    gcc
  ];

  # Generous limits for the postgres/bench user.
  security.pam.loginLimits = [
    { domain = "*"; type = "soft"; item = "memlock"; value = "unlimited"; }
    { domain = "*"; type = "hard"; item = "memlock"; value = "unlimited"; }
    { domain = "*"; type = "soft"; item = "nofile"; value = "1048576"; }
    { domain = "*"; type = "hard"; item = "nofile"; value = "1048576"; }
  ];

  # CPU performance governor (don't let the instance downclock mid-benchmark).
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  # Headless cloud host: no firmware updates (fwupd pulls in udisks2=true,
  # which conflicts with the amazon-image profile's udisks2=false). Disable
  # both — useless on EC2 and resolves the conflict.
  services.fwupd.enable = lib.mkForce false;
  services.udisks2.enable = lib.mkForce false;

  # Cloud/headless: no X server, so console.useXkbConfig (which derives the
  # keymap from xkb) has nothing to resolve from and yields a non-string
  # keyMap. Force a plain console keymap and drop the xkb derivation.
  console.useXkbConfig = lib.mkForce false;
  console.keyMap = lib.mkForce "us";
}
