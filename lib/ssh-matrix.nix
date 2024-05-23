_:
let
  parseFriendlyKey = builtins.replaceStrings [ "\n" ] [ "" ];
in
rec {
  # user@host matrix
  systems = {
    floki.gburd = parseFriendlyKey ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGSNy/vMr2Zk9pvfjQnxiU9F8CGQ
      JwCiXDxPecKG9/q+ Greg Burd <greg@burd.me> - 2023-01-23
    '';

    symas.gburd = parseFriendlyKey ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDPvS6pE5Y8Yc3YnKpKinjVKyziq
      nb7JZJGonDKnZi3I Greg Burd <gburd@symas.com> - 2023-08-03
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
      floki.gburd
      symas.gburd
      floki.host
      floki.root
      #      pixel6a.nix-on-droid
    ];
  };
}
