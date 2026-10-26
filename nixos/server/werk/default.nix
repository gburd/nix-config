# werk -- x86_64 NixOS on EC2 (m6idn.12xlarge), HEADLESS. A "headless floki":
# the same nixos/ tree (sshd, firejail, oomd, scratch, gburd user) with no
# desktop and the EC2 amazon-image boot layer instead of workstation hardware.
#
# Deploy from a dev box (floki) over the tailnet once werk is on Headscale:
#   nixos-rebuild switch --fast --flake .#werk \
#     --target-host gburd@werk.ts.burd.me --build-host gburd@werk.ts.burd.me --use-remote-sudo
# or locally on werk: sudo nixos-rebuild switch --flake .#werk
#
# Disks: a 64 GiB EBS root (/ and /nix) plus two instance-store NVMe striped
# RAID0 for /home and /scratch. The stripe is EPHEMERAL: it survives a reboot
# but comes back blank after a stop or a host move, so local-nvme (below)
# creates+formats it when blank and reassembles it otherwise. Anything on the
# stripe that is not pushed with git is at risk on a host retirement.
{ modulesPath, lib, pkgs, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")

    # Auto-authenticate to our Headscale via the sops-managed reusable key.
    # werk's host age key is enrolled in .sops.yaml so it can decrypt
    # nixos/_mixins/secrets.yaml (gburd-password + tailscale-auth-key).
    ../../_mixins/services/tailscale-autoconnect.nix
  ];

  networking.hostName = "werk";
  nixpkgs.hostPlatform = "x86_64-linux";

  # No firmware to flash on a VM; fwupd pulls in udisks2, which amazon-image
  # disables (hard), so the two collide. Turn fwupd off on EC2.
  services.fwupd.enable = lib.mkForce false;

  # Headless: no XKB console remap (the shared tree's useXkbConfig builds an
  # xkb keymap derivation that collides with a plain keyMap on EC2).
  console.useXkbConfig = lib.mkForce false;
  console.keyMap = lib.mkForce "us";

  # Passwordless sudo for wheel (gburd). The nix-config tree otherwise relies
  # on pam_ssh_agent_auth, which needs a forwarded agent; on a headless EC2
  # box reached over plain SSH that is awkward, and werk is a trusted
  # single-user host. gburd still has a login password (sops gburd-password).
  security.sudo.wheelNeedsPassword = false;
  # !use_pty: sudo's TTY requirement fails in non-interactive SSH/systemd
  # contexts (remote nixos-rebuild, scripts). lecture=never: quiet.
  security.sudo.extraConfig = ''
    Defaults lecture = never
    Defaults !use_pty
  '';

  # Dev-workstation base, cherry-picked from _mixins/workstations/common.nix
  # (werk does NOT import that whole mixin: it is desktop-oriented
  # (1Password-GUI, pipewire, bluetooth, avahi, NetworkManager/resolved,
  # systemd-boot) and would fight amazon-image on a headless DHCP EC2 box).
  # These are the host-type-agnostic pieces a primary dev host needs.
  # shortcut: inlined here; extract a shared server-common mixin when a
  # SECOND dev server wants the identical block.

  # nix-ld: run dynamically linked non-NixOS binaries (uv/pipx pull their own
  # standalone builds for the litellm proxy; without this they fail with
  # "NixOS cannot run dynamically linked executables"). This was THE blocker
  # for `home-manager switch` on werk.
  programs.nix-ld.enable = true;
  # FHS paths (/usr/bin/env, /bin/sh); the system half of the HM .envrc's
  # ENVFS_RESOLVE_ALWAYS=1.
  services.envfs.enable = true;
  # trippy (`trip`): setcap raw-socket wrapper so it runs without sudo.
  programs.trippy.enable = true;
  # gdb/lldb/strace attach to a running process without sudo (single-user box).
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 0;
  # Cross-build aarch64 (and armv7l) via qemu binfmt. Lets werk build the
  # agent-sandbox Arm EC2 template if buildAarch64 is ever flipped on; slow
  # (emulated) but available.
  boot.binfmt.emulatedSystems = [ "armv7l-linux" "aarch64-linux" ];

  # OOM protection (from common.nix, scaled for werk's 185 GiB). werk runs
  # the pi fleet + heavy builds and has no swap, so give the kernel room to
  # reclaim and rank a runaway BUILD above the session daemons.
  #   * zram at a modest 15% (~28 GiB uncompressed headroom): the real OOM
  #     defense here is the nix-daemon MemoryMax cap, not swap, and this box
  #     is for big builds, not a swap-heavy desktop.
  #   * user@ session daemons rank below builds; nix-daemon builds are capped
  #     and OOM-killed INSIDE the daemon instead of taking the session.
  zramSwap = {
    enable = true;
    memoryPercent = 15;
  };
  systemd.services."user@".serviceConfig.OOMScoreAdjust = 0;
  systemd.services.nix-daemon.serviceConfig = {
    MemoryHigh = "70%";
    MemoryMax = "85%";
    OOMScoreAdjust = 500;
  };

  # amazon-image gives us grub + the ENA/NVMe initrd modules; keep root login
  # off (key-only gburd + wheel passwordless sudo come from the nixos/ tree).
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

  # The instance-store NVMe drives hold /home and /scratch. They survive a
  # reboot but come back blank after a stop or a host move, so assemble (or
  # create) a RAID0 stripe, format it only when it has no filesystem, and
  # bind-mount /home and /scratch from it. Runs before sshd/user-sessions so
  # a login lands on a populated /home even right after a cold stripe build.
  boot.swraid.enable = true;
  boot.swraid.mdadmConf = "MAILADDR root";
  systemd.services.local-nvme = {
    description = "Assemble and mount the instance-store NVMe stripe";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    before = [ "sshd.service" "systemd-user-sessions.service" ];
    path = with pkgs; [ mdadm xfsprogs util-linux coreutils gawk ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      set -euo pipefail
      dev=$(blkid -L local || true)
      if [ -z "$dev" ]; then
        mdadm --assemble --scan || true
        dev=$(blkid -L local || true)
      fi
      if [ -z "$dev" ]; then
        disks=$(lsblk -dnpo NAME,MODEL | awk '/Instance Storage/ { print $1 }')
        n=$(echo "$disks" | wc -w)
        [ "$n" -gt 0 ] || { echo "no instance-store NVMe found" >&2; exit 1; }
        mdadm --create /dev/md/local --run --force --level=0 \
          --raid-devices="$n" --name=local $disks
        mkfs.xfs -f -L local /dev/md/local
        dev=/dev/md/local
      fi
      mkdir -p /local
      mountpoint -q /local || mount -o noatime "$dev" /local
      mkdir -p /local/home /local/scratch /scratch
      mountpoint -q /home || mount --bind /local/home /home
      mountpoint -q /scratch || mount --bind /local/scratch /scratch
      install -d -o gburd -g users -m 0700 /home/gburd
      chown gburd:users /local/scratch
    '';
  };
}
