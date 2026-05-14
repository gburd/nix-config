{ pkgs, ... }:
{
  # borgbackup is provided by services/borgmatic.nix; vorta is the GUI frontend
  home.packages = with pkgs; [
    vorta
  ];

  systemd.user.services = {
    vorta = {
      Unit = {
        Description = "Vorta";
      };
      Service = {
        ExecStart = "${pkgs.vorta}/bin/vorta --daemonise";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
