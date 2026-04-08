{ pkgs, config, ... }:
{
  programs.khal.enable = true;

  xdg.configFile."khal/config".text = ''
    [default]
    default_calendar = google-personal
    timedelta = 7d

    [view]
    agenda_event_format = {calendar-color}{cancelled}{start-end-time-style} {title}{repeat-symbol}

    [[calendars.google_personal]]
    path = ${config.home.homeDirectory}/.local/share/calendars/google-personal/*
    color = light blue
    priority = 10

    [[calendars.google_work]]
    path = ${config.home.homeDirectory}/.local/share/calendars/google-work/*
    color = light green
    priority = 20

    [[calendars.icloud]]
    path = ${config.home.homeDirectory}/.local/share/calendars/icloud/*
    color = light magenta
    priority = 30

    [[calendars.outlook]]
    path = ${config.home.homeDirectory}/.local/share/calendars/outlook/*
    color = light cyan
    priority = 40
  '';
}
