{ pkgs, ... }: {
  environment.systemPackages = with pkgs.unstable; [
    ungoogled-chromium
  ];

  programs = {
    ungoogled-chromium = {
      enable = true;
      extensions = [
        "cdglnehniifkbagbbombnjghhcihifij" # kagi-search-for-chrome
        #"ghmbeldphafepmbegfdlkpapadhbakde" # proton-pass-free-password
        "chphlpgkkbolifaimnlloiipkdnihall" # OneTab
      ];
      extraOpts = {
        "AutofillAddressEnabled" = false;
        "AutofillCreditCardEnabled" = false;
        "BuiltInDnsClientEnabled" = false;
        "DeviceMetricsReportingEnabled" = true;
        "ReportDeviceCrashReportInfo" = false;
        "PasswordManagerEnabled" = false;
        "SpellcheckEnabled" = true;
        "SpellcheckLanguage" = [
          "en-US"
        ];
        "VoiceInteractionHotwordEnabled" = false;
      };
    };
  };
}
