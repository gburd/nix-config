{ config, ... }:
let hostname = config.networking.hostName;
in {
  boot.initrd = {
    # Enable swap on luks
    luks.devices."luks-3b6dddfd-5390-441f-a72d-a3b2809204df".device = "/dev/disk/by-uuid/3b6dddfd-5390-441f-a72d-a3b2809204df";

    # Setup encrypted root keyfile
    luks.devices."luks-3b6dddfd-5390-441f-a72d-a3b2809204df".keyFile = "/crypto_keyfile.bin";
    secrets = {
      "/crypto_keyfile.bin" = null;
    };
  };

}
