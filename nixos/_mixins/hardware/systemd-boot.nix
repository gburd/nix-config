_: {
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        configurationLimit = 10;
        consoleMode = "max";
        enable = true;
        memtest86.enable = true;
      };
      timeout = 10;
    };
  };
}
