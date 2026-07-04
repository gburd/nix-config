{ lib, pkgs, modulesPath, ... }:
# agent-vm — minimal NixOS guest for agent-sandbox's `microvm` tier (full
# QEMU hardware-virtualised kernel isolation). Based on nixpkgs' qemu-vm.nix,
# which handles the host /nix/store overlay + 9p correctly. agent-sandbox
# runs `config.system.build.vm`, passing the CURRENT project + a command dir
# as EXTRA 9p shares via $QEMU_OPTS (no per-project rebuild).
#
# Isolation: clean guest rootfs (no host $HOME/.ssh/secrets/.aws). The guest
# reaches the host LiteLLM gateway (127.0.0.1:4000) via slirp at 10.0.2.2:4000.
{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
  system.stateVersion = "25.11";

  virtualisation = {
    memorySize = lib.mkDefault 4096;
    cores = lib.mkDefault 4;
    graphics = false;
    diskImage = null; # ephemeral: no persistent disk, tmpfs root
    # Extra 9p mounts (project + cmd) are injected at boot by agent-sandbox
    # via QEMU_OPTS; declare where they mount.
  };

  # The project is shared via qemu-vm.nix's built-in 'shared' 9p mount
  # (host SHARED_DIR -> guest /tmp/shared). We symlink /project -> /tmp/shared
  # for convenience. The COMMAND is passed on the kernel cmdline (agentcmd=
  # base64), which is reliable (extra -virtfs via QEMU_OPTS is not).
  systemd.tmpfiles.rules = [ "L+ /project - - - - /tmp/shared" ];

  users.users.agent = {
    isNormalUser = true;
    uid = 1000;
    home = "/home/agent";
  };
  services.getty.autologinUser = "agent";

  networking.firewall.enable = false;
  networking.hostName = "agent-vm";

  environment.systemPackages = with pkgs; [ git openssh curl jq coreutils bashInteractive nodejs gnused ];
  environment.variables = {
    ANTHROPIC_BASE_URL = "http://10.0.2.2:4000";
    LITELLM_GATEWAY = "http://10.0.2.2:4000";
  };

  # Run the shared command (/cmd/run), then power off. Robust against 9p
  # mount timing: wait for the shares rather than hard-depending on .mount
  # units (brittle with QEMU_OPTS-injected virtfs).
  systemd.services.agent-run = {
    description = "Run the sandboxed agent command from /cmd, then power off";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "agent";
      ExecStart = pkgs.writeShellScript "agent-vm-run" ''
        set +e
        # Wait for the project ('shared') 9p mount.
        for _ in $(seq 1 40); do
          ${pkgs.util-linux}/bin/mountpoint -q /tmp/shared && break
          sleep 0.5
        done
        cd /tmp/shared 2>/dev/null || cd /home/agent
        # Command comes in on the kernel cmdline as agentcmd=<base64>.
        CMD=$(${pkgs.coreutils}/bin/tr ' ' '\n' < /proc/cmdline \
          | ${pkgs.gnugrep}/bin/grep '^agentcmd=' | ${pkgs.coreutils}/bin/cut -d= -f2- \
          | ${pkgs.coreutils}/bin/base64 -d 2>/dev/null)
        if [ -n "$CMD" ]; then
          ${pkgs.bashInteractive}/bin/bash -lc "$CMD"
        else
          echo "agent-vm: no agentcmd= on cmdline; interactive shell" >&2
          ${pkgs.bashInteractive}/bin/bash -l
        fi
      '';
      ExecStopPost = "${pkgs.systemd}/bin/systemctl poweroff";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
  };

  documentation.enable = false;
}
