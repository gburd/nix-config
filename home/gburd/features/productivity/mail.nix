{ pkgs, lib, config, ... }:

let
  mbsync = "${config.programs.mbsync.package}/bin/mbsync";
  pass = "${config.programs.password-store.package}/bin/pass";

  common = rec {
    realName = "Greg Burd";
    gpg = {
      key = "D4BB42BE729AEFBD2EFEBF8822931AF7895E82DF";
      signByDefault = true;
    };
    signature = {
      showSignature = "append";
      text = ''
        ${realName}

        https://burd.me
        PGP: ${gpg.key}
      '';
    };
  };
in
{
  home.persistence = {
    "/persist/home/gburd".directories = [ "Mail" ];
  };

  accounts.email = {
    maildirBasePath = "Mail";
    accounts = {
      personal = rec {
        primary = true;
        address = "greg@burd.me";
        aliases = ["gregburd@gmail.com"];
        passwordCommand = "${pass} ${smtp.host}/${address}";

        imap.host = "mail.burd.me";
        mbsync = {
          enable = true;
          create = "maildir";
          expunge = "both";
        };
        folders = {
          inbox = "Inbox";
          drafts = "Drafts";
          sent = "Sent";
          trash = "Trash";
        };
        neomutt = {
          enable = true;
          extraMailboxes = [ "Archive" "Drafts" "Junk" "Sent" "Trash" ];
        };

        msmtp.enable = true;
        smtp.host = "mail.burd.me";
        userName = address;
      } // common;

      symas = rec {
        address = "gburd@symas.com";
        passwordCommand = "${pass} ${smtp.host}/${address}";

        /* TODO: add imap (conditionally)
        imap.host = "symas.zmailcloud.com";
        mbsync = {
          enable = true;
          create = "maildir";
          expunge = "both";
        };
        folders = {
          inbox = "INBOX";
          trash = "Trash";
        };
        neomutt = {
          enable = true;
        };
        */

        msmtp.enable = true;
        smtp.host = "symas.zmailcloud.com";
        userName = address;
      } // common;
    };
  };

  programs.mbsync.enable = true;
  programs.msmtp.enable = true;

  systemd.user.services.mbsync = {
    Unit = { Description = "mbsync synchronization"; };
    Service =
      let gpgCmds = import ../cli/gpg-commands.nix { inherit pkgs; };
      in
      {
        Type = "oneshot";
        ExecCondition = ''
          /bin/sh -c "${gpgCmds.isUnlocked}"
        '';
        ExecStart = "${mbsync} -a";
      };
  };
  systemd.user.timers.mbsync = {
    Unit = { Description = "Automatic mbsync synchronization"; };
    Timer = {
      OnBootSec = "30";
      OnUnitActiveSec = "5m";
    };
    Install = { WantedBy = [ "timers.target" ]; };
  };
}
