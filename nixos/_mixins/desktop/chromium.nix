{ pkgs, ... }: {
  environment.systemPackages = with pkgs.unstable; [
    chromium
  ];

  programs = {
    chromium = {
      enable = true;
      extensions = [
        "cdglnehniifkbagbbombnjghhcihifij" # Kagi Search
        "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
        "lckanjgmijmafbedllaakclkaicjfmnk" # ClearURLs
        "lkbebcjgcmobigpeffafkodonchffocl" # Bypass Paywalls Clean
        "mdjildafknihdffpkfmmpnpoiajfjnjd" # Consent-O-Matic
        "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock for YouTube
        "gebbhagfogifgggkldgodflihgfeippi" # Return YouTube Dislike
        "edlifbnjlicfpckhgjhflgkeeibhhcii" # Screenshot Tool
        "chphlpgkkbolifaimnlloiipkdnihall" # OneTab
        "khgocmkkpikpnmmkgmdnfckapcdkgfaf" # 1Password Beta
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
