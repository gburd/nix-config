_:
# gburd's ssh client defaults (multiplexing, keepalives, host-key policy). Plain
# OpenSSH directives, so it is shared by every host including the solnix
# (illumos) ones, which import it from home-manager/solnix.nix.
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # 26.05: matchBlocks -> settings; block key is the Host pattern, fields
    # use upstream OpenSSH directive names, and the old extraOptions nesting
    # is gone (those were already OpenSSH directives -> merge in flat).
    settings = {
      "*" = {
        # No global IdentityAgent: SSH auth + git signing now use the
        # sops-deployed on-disk keys (~/.ssh/id_auth_ed25519 /
        # id_signing_ed25519) via the standard ssh-agent
        # (modules/home-manager/ssh-management). 1Password's agent socket
        # required an unlocked, non-auto-locked GUI app to sign — unusable
        # headless/over-SSH — so it's no longer wired here.
        Compression = true;
        ConnectTimeout = "5";
        ControlMaster = "auto";
        ControlPath = "/tmp/ssh_mux_%h_%p_%r";
        ControlPersist = "10m";
        LogLevel = "QUIET";
        ServerAliveInterval = "60";
        ServerAliveCountMax = "2";
        TCPKeepAlive = "yes";
        # accept-new: trust a host on FIRST contact (no prompt) but
        # WARN+refuse if a known host's key later changes — i.e. keep
        # the MITM protection that StrictHostKeyChecking=no +
        # UserKnownHostsFile=/dev/null threw away. Real known_hosts so
        # changes are actually detected. ForwardAgent/ForwardX11 are
        # deliberately NOT set globally: they're scoped per-trusted-
        # host in cli/ssh.nix (net/trusted/meh/santorini blocks).
        StrictHostKeyChecking = "accept-new";
      };
      # Throwaway / ephemeral local targets (quickemu VMs, freshly-imaged
      # boxes, link-local) where the host key churns and there's nothing
      # to MITM. Here — and ONLY here — skip verification.
      "Host 192.168.122.* 10.0.2.* *.local quickemu vm-*" = {
        StrictHostKeyChecking = "no";
        UserKnownHostsFile = "/dev/null";
      };
      "github.com" = {
        HostName = "github.com";
        User = "git";
      };
    };
  };
}
