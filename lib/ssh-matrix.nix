_:
let
  parseFriendlyKey = builtins.replaceStrings [ "\n" ] [ "" ];
in
rec {
  # user@host matrix
  systems = {
    # gburd's EVERYDAY key, ~/.ssh/id_ed25519 (SHA256:m19Q...). It is on
    # floki, arnold and nuc, and is what the Windows host santorini
    # authorizes. NixOS hosts listed only the 2023 key below (cBEQ...), so
    # they accepted m19Q only if a hand-made ~/.ssh/authorized_keys added it.
    # meh had one; wix did not, so `ssh wix` failed with Permission denied
    # from every tailnet node (2026-10-14). Declared here, it reaches every
    # host that uses privileged_users.
    gburd.everyday = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKCqHOIyYwbp42C7MxnRFxOcy+ZE8cNOWdsdvCgVFm1L greg@burd.me";
    # gburd's AUTH key, ~/.ssh/id_auth_ed25519 (SHA256:yaU3...). The EC2 launch
    # key (gburd-floki-auth); ECDSA can't be imported to EC2, so this ed25519
    # is the key pair new instances boot with. Used for admin login + sudo
    # (pam_ssh_agent_auth) across hosts; declared here so it reaches every
    # host that uses privileged_users.
    gburd.auth = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO6HS8oDnpvGKTisMx38pq1I3YJP4+ds7WIYF+L578dW greg@burd.me-auth-floki-202604";
    # gburd's work laptop (macOS, 80a99738d7e2), ~/.ssh/id_ecdsa
    # (SHA256:emnU...).  EC2 can't import ECDSA keys, so hosts launched with
    # gburd.auth only accept this key once it is declared here.
    gburd.laptop = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJF+rlM1Iwj6TsDCndPQ5Pec0Np8uFBIutDLaeAqwWKujhYwnT3hLiHGoCewbYJYt+YsO9YhddhKO/Ai+G5CqwM= gregburd@80a99738d7e2";
    floki.gburd = parseFriendlyKey ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGSNy/vMr2Zk9pvfjQnxiU9F8CGQ
      JwCiXDxPecKG9/q+ Greg Burd <greg@burd.me> - 2023-01-23
    '';

    floki = {
      host = parseFriendlyKey ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKG7dVoHbOjQ/i45ATeli7mYLl1b
        Q8zBKbmg5t9xi1Yl root@nixos
      '';
      root = parseFriendlyKey ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8hXaBle8TPkKPa2vKcmfH66y+
        iW5YZn68COvLSdcstXZPOxErGcfp9oTS/HJdUctEVLygEAfVSTQst0q9xpyAqSyE
        t8VqJiHXUZEwFs3erGT8yF+6EF6FueMqGynAUXNkGz9XKv02/w66AWWGekgc1B8A
        VK0+aqeTES5PPlynUDpZIAhDm9C2zR5IgsUT68vxfodz0Srfjx6tXNwBShfIToky
        ZznUOz9QVvN6bqaczYm2RxhuWyp2qVLUFSL2ksQErb2cq57Q5B7y+DIh5yJaELSs
        Ghdzb+UAC/SsLYKRIJMCaT69XL8BogHdiTV4WPK0E5d3Xs6hBm5mHeawIRIKw0rv
        xJG/Dtq2q7GwGQPHY8kgvvZBJYm9o9wExeWi0fz5ZzxtfMldZk1Exd1TDouXIrhz
        jodAlL06s5h2QLMv3sDnn7AlfVyPcDE4qhAl5KLBO1/uD/RLG52Zw3jj+8B4UwHy
        4YxQbqFkk0t9TvASEY19REN6N6x+OPoHHWiJ5CCwik2QqY7cXoiQYqSQT8uhgqsc
        xxt0Lfj+JScESoHsi8o4FNoIvuDu5V0jTG6Qou+UOU6KGRHpwokYgwnH5b+o29ce
        3WbujcLiSXsmu2+gP1231usgUfEz/uiutowROngAys8ivY3Zdoyu7qyWdZhie/e5
        BAPmRo042eWMzBWQbQ== root@nixos
      '';
    };

    # pixel6a = {
    #   nix-on-droid = parseFriendlyKey ''
    #   '';
    # };

    # # NUC servers
    # nuc0.host = "ssh-ed25519 ABBAC3NzaC1lZDI1NTE5AAAAIHkgTzsmgHcVE12Sc9EYPP29Ek8d++RKZCIVEGEmWJc9 nuc0.int.burd.dev";
  };

  # logical groups
  groups = {
    privileged_users = with systems; [
      gburd.everyday
      gburd.auth
      gburd.laptop
      floki.gburd
      floki.host
      floki.root
      #      pixel6a.nix-on-droid
    ];
  };
}
