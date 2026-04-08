{ config, pkgs, ... }:
{
  home.packages = [ pkgs.vdirsyncer ];

  xdg.configFile."vdirsyncer/config".text = ''
    [general]
    status_path = "~/.local/share/vdirsyncer/status/"

    # Google Personal Calendar
    [pair google_personal]
    a = "google_personal_local"
    b = "google_personal_remote"
    collections = ["from a", "from b"]
    conflict_resolution = "b wins"

    [storage google_personal_local]
    type = "filesystem"
    path = "~/.local/share/calendars/google-personal"
    fileext = ".ics"

    [storage google_personal_remote]
    type = "google_calendar"
    token_file = "~/.local/share/vdirsyncer/google_personal_token"
    client_id.fetch = ["command", "cat", "${config.sops.secrets."calendar/google/personal/client-id".path}"]
    client_secret.fetch = ["command", "cat", "${config.sops.secrets."calendar/google/personal/secret".path}"]

    # Google Work Calendar
    [pair google_work]
    a = "google_work_local"
    b = "google_work_remote"
    collections = ["from a", "from b"]
    conflict_resolution = "b wins"

    [storage google_work_local]
    type = "filesystem"
    path = "~/.local/share/calendars/google-work"
    fileext = ".ics"

    [storage google_work_remote]
    type = "google_calendar"
    token_file = "~/.local/share/vdirsyncer/google_work_token"
    client_id.fetch = ["command", "cat", "${config.sops.secrets."calendar/google/pgus/client-id".path}"]
    client_secret.fetch = ["command", "cat", "${config.sops.secrets."calendar/google/pgus/secret".path}"]

    # iCloud Calendar
    [pair icloud]
    a = "icloud_local"
    b = "icloud_remote"
    collections = ["from a", "from b"]
    conflict_resolution = "b wins"

    [storage icloud_local]
    type = "filesystem"
    path = "~/.local/share/calendars/icloud"
    fileext = ".ics"

    [storage icloud_remote]
    type = "caldav"
    url = "https://caldav.icloud.com/"
    username.fetch = ["command", "cat", "${config.sops.secrets."calendar/apple/icloud/user".path}"]
    password.fetch = ["command", "cat", "${config.sops.secrets."calendar/apple/icloud/pass".path}"]

    # Outlook Calendar
    [pair outlook]
    a = "outlook_local"
    b = "outlook_remote"
    collections = ["from a", "from b"]
    conflict_resolution = "b wins"

    [storage outlook_local]
    type = "filesystem"
    path = "~/.local/share/calendars/outlook"
    fileext = ".ics"

    [storage outlook_remote]
    type = "caldav"
    url = "https://outlook.office365.com/EWS/Exchange.asmx/CalDav/"
    username.fetch = ["command", "cat", "${config.sops.secrets."calendar/ms/outlook/user".path}"]
    password.fetch = ["command", "cat", "${config.sops.secrets."calendar/ms/outlook/pass".path}"]
  '';

  systemd.user.services.vdirsyncer = {
    Unit = {
      Description = "Synchronize calendars";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.vdirsyncer}/bin/vdirsyncer sync";
    };
  };

  systemd.user.timers.vdirsyncer = {
    Unit = {
      Description = "Sync calendars every 15 minutes";
    };
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "15min";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # Create directories
  home.file = {
    ".local/share/vdirsyncer/.keep".text = "";
    ".local/share/calendars/google-personal/.keep".text = "";
    ".local/share/calendars/google-work/.keep".text = "";
    ".local/share/calendars/icloud/.keep".text = "";
    ".local/share/calendars/outlook/.keep".text = "";
  };
}
