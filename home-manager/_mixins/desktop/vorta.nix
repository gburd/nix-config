{ config, lib, pkgs, ... }:
let
  # Repo/profile values to seed. Hostname goes into the source dir indirectly
  # (config.home.homeDirectory points at /home/<user>); host doesn't appear in
  # repo name because we share one repo across floki/meh.
  repoUrl = "ssh://zh6216@zh6216.rsync.net/./borg";
  repoName = "rsync-net";
  borgKey = "${config.home.homeDirectory}/.config/borgmatic/.rsync-key";
  borgPassFile = "${config.home.homeDirectory}/.config/borgmatic/.passphrase";
in
{
  # borgbackup is provided by services/borgmatic.nix; vorta is the GUI frontend
  # for browsing/restoring archives. Imported only on hosts that have a
  # desktop session (floki, meh); arnold is headless and doesn't import this.
  home.packages = with pkgs; [
    vorta
  ];

  systemd.user.services = {
    vorta = {
      Unit = {
        Description = "Vorta";
        # Vorta is a Qt GUI - it must NOT start until the user's graphical
        # session is up (DISPLAY / WAYLAND_DISPLAY exported into the
        # systemd-user environment). With the previous WantedBy=default.target,
        # the daemon raced login on every reboot, hit Qt platform-plugin init
        # failures, crashed with SIGABRT, restarted 5x in 5s, and got marked
        # failed by systemd's burst limiter ("Start request repeated too
        # quickly").
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.vorta}/bin/vorta --daemonise";
        Restart = "on-failure";
        # Pause between restarts so a transient crash doesn't burn through the
        # default 5-fast-restarts-in-10s limit and end up permanently failed.
        RestartSec = 5;
        # Light sandbox only — Vorta is a Qt GUI that needs the display,
        # the secret-service, and (via borg) broad home access, so the
        # strict filesystem/namespace protections used on daemon services
        # would break it. These three are safe and free.
        NoNewPrivileges = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
      };
      Install = {
        # Tie lifecycle to the graphical session: Vorta starts when GNOME
        # comes up and stops when the session ends. Avoids the start-before-
        # display race entirely.
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };

  # ----------------------------------------------------------------------
  # Declarative seeding of Vorta's profile/repo/passphrase
  # ----------------------------------------------------------------------
  # Vorta has no CLI for adding repos; everything goes through its GUI and is
  # persisted to ~/.local/share/Vorta/settings.db (SQLite). We seed that DB
  # at home-manager activation time so a fresh host has the rsync-net repo,
  # a "Default" profile pointing at it (with the sops-deployed SSH key path),
  # and the borg passphrase already populated -- no GUI dance.
  #
  # Idempotency:
  #   - repomodel and repopassword have UNIQUE indexes on `url`, so we use
  #     INSERT OR IGNORE; user-edited rows are not overwritten.
  #   - backupprofilemodel and sourcedirmodel use WHERE NOT EXISTS guards
  #     keyed on (repo url, dir); subsequent activations are no-ops.
  #
  # Schema versioning:
  #   - vorta-schema.sql is a snapshot of Vorta 0.10.3's v23 schema. Vorta
  #     runs migrations on every launch, so if Vorta upgrades to v24+ on a
  #     host where we created the DB at v23, the user's first launch
  #     migrates forward normally. To refresh the snapshot:
  #       sqlite3 ~/.local/share/Vorta/settings.db .schema | sort -u \
  #         > home-manager/_mixins/desktop/vorta-schema.sql
  home.activation.seedVortaProfile =
    let
      # Build the seed script in the Nix store so its content is fixed and
      # not subject to indented-string reformatting hazards. Nix interpolates
      # the path/url/etc. into the file at build time; bash runs the result
      # at activation time.
      seedScript = pkgs.writeShellScript "vorta-seed" ''
        set -eu
        SQLITE=${pkgs.sqlite}/bin/sqlite3
        VORTA_DIR=${config.home.homeDirectory}/.local/share/Vorta
        DB="$VORTA_DIR/settings.db"
        PASS_FILE=${borgPassFile}
        SCHEMA=${./vorta-schema.sql}

        ${pkgs.coreutils}/bin/mkdir -p "$VORTA_DIR"
        ${pkgs.coreutils}/bin/chmod 700 "$VORTA_DIR"

        # Create the DB with Vorta's v23 schema if it doesn't exist yet.
        if [ ! -f "$DB" ]; then
          "$SQLITE" "$DB" < "$SCHEMA"
          "$SQLITE" "$DB" "INSERT INTO schemaversion (version, changed_at) VALUES (23, datetime('now'));"
          ${pkgs.coreutils}/bin/chmod 600 "$DB"
          echo "vorta-seed: created $DB with schema v23"
        fi

        # Read the borg passphrase from the sops-deployed file. If sops hasn't
        # run yet (first activation order), skip the password seed; the next
        # switch picks it up. Escape single quotes for SQL by doubling them.
        ESC_PASS=""
        if [ -r "$PASS_FILE" ]; then
          PASS=$(${pkgs.coreutils}/bin/cat "$PASS_FILE")
          ESC_PASS=$(printf '%s' "$PASS" | ${pkgs.gnused}/bin/sed "s/'/'''/g")
        else
          echo "vorta-seed: $PASS_FILE not yet readable; skipping passphrase seed"
        fi

        # Idempotent seed: repo, profile, source directory.
        "$SQLITE" "$DB" <<SQL
        BEGIN TRANSACTION;

        -- 1. Repository (url is UNIQUE).
        INSERT OR IGNORE INTO repomodel
          (url, added_at, encryption, create_backup_cmd, extra_borg_arguments, name)
          VALUES ('${repoUrl}', datetime('now'), 'key file BLAKE2b', ''', '--remote-path borg1', '${repoName}');

        -- 2. Default profile linked to that repo. Mirrors floki's working
        --    config (lz4 compression, schedule disabled, archive-name format).
        --    Idempotent via WHERE NOT EXISTS keyed on repo_id.
        INSERT INTO backupprofilemodel
          (name, added_at, repo_id, ssh_key, compression,
           exclude_patterns, exclude_if_present,
           schedule_mode, schedule_interval_count, schedule_interval_unit,
           schedule_fixed_hour, schedule_fixed_minute,
           schedule_interval_hours, schedule_interval_minutes,
           schedule_make_up_missed,
           validation_on, validation_weeks,
           prune_on, prune_hour, prune_day, prune_week, prune_month, prune_year,
           prune_keep_within, new_archive_name, prune_prefix,
           pre_backup_cmd, post_backup_cmd,
           dont_run_on_metered_networks, compaction_on, compaction_weeks)
        SELECT 'Default', datetime('now'), r.id, '${borgKey}', 'lz4',
               NULL, ''',
               'off', 3, 'hours',
               3, 42,
               3, 42,
               1,
               1, 3,
               0, 2, 7, 4, 6, 2,
               '10H', '{hostname}-{now:%Y-%m-%d-%H%M%S}', '{hostname}-',
               ''', ''',
               1, 1, 3
          FROM repomodel r
          WHERE r.url = '${repoUrl}'
            AND NOT EXISTS (SELECT 1 FROM backupprofilemodel WHERE repo_id = r.id);

        -- 3. Source directory (\$HOME) for the profile.
        INSERT INTO sourcedirmodel
          (dir, dir_size, dir_files_count, path_isdir, profile_id, added_at)
        SELECT '${config.home.homeDirectory}', 0, 0, 1, p.id, datetime('now')
          FROM backupprofilemodel p
          JOIN repomodel r ON p.repo_id = r.id
          WHERE r.url = '${repoUrl}'
            AND NOT EXISTS (
              SELECT 1 FROM sourcedirmodel
                WHERE profile_id = p.id AND dir = '${config.home.homeDirectory}'
            );

        COMMIT;
SQL

        # Passphrase as a separate statement: the password value goes in
        # SQL via single-argument quoting rather than a heredoc, which
        # avoids any heredoc-substitution surprises in the passphrase. url
        # is UNIQUE, so this is idempotent.
        if [ -n "$ESC_PASS" ]; then
          "$SQLITE" "$DB" "INSERT OR IGNORE INTO repopassword (url, password) VALUES ('${repoUrl}', '$ESC_PASS');"
        fi

        ${pkgs.coreutils}/bin/chmod 600 "$DB"
      '';
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${seedScript}
    '';
}
