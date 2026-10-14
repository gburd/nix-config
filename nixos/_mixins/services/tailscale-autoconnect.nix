{ config, lib, pkgs, ... }:
{
  imports = [ ./tailscale.nix ];

  # Per-host override for the name this node registers under in the tailnet.
  # Defaults to the system hostname; set it when the OS hostname would collide
  # with an existing node (e.g. santorini's WSL guest shares the "santorini"
  # name with the Windows host, so tailscale would suffix it to "santorini-1").
  options.services.tailscaleAutoconnect.hostname = lib.mkOption {
    type = lib.types.str;
    default = config.networking.hostName;
    description = "Hostname to register this node under in Tailscale.";
  };

  # ---------------------------------------------------------------
  # Auto-authenticated Tailscale (sops-nix-driven)
  # ---------------------------------------------------------------
  # When this module is imported on a host, Tailscale is brought up
  # automatically using a reusable auth key stored in
  # ~/ws/nix-config/nixos/_mixins/secrets.yaml under the key
  #   tailscale-auth-key
  #
  # The one-shot systemd service is idempotent: it inspects the
  # current backend state via `tailscale status -json`. If the host
  # is already "Running" (i.e. /var/lib/tailscale/ has a valid
  # session), it exits without touching anything; the auth key is
  # only used on first activation or after the persistent state
  # gets wiped (re-install, /var disk reformat, etc.).
  #
  # To provision the key:
  #   1. Mint a reusable key on OUR Headscale (not tailscale.com):
  #        flyctl ssh console -a burd-headscale \
  #          -C "headscale preauthkeys create --user 1 --reusable -e 2160h"
  #      (--user takes the numeric id; `headscale users list`.)
  #   2. Store it without putting it on argv:
  #        sops set --value-stdin nixos/_mixins/secrets.yaml \
  #          '["tailscale-auth-key"]' <<< '"hskey-auth-..."'
  #   3. `sudo nixos-rebuild switch --flake .#<host>`
  #
  # A leftover tskey-* (Tailscale SaaS) key is refused below: it would make
  # a fresh host fail against Headscale with "invalid key" anyway.
  #
  # If the secret is missing the activation will fail loudly. To opt
  # back to manual `tailscale up`, drop this import and import
  # ./tailscale.nix directly.
  # ---------------------------------------------------------------

  config = {
    sops.secrets.tailscale-auth-key = {
      sopsFile = ../../_mixins/secrets.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "tailscale-autoconnect.service" ];
    };

    systemd.services.tailscale-autoconnect = {
      description = "Bring Tailscale up automatically (one-shot, idempotent)";

      after = [ "network-pre.target" "tailscale.service" "sops-nix.service" ];
      wants = [ "network-pre.target" "tailscale.service" "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Surface failures clearly in journalctl rather than silently retrying
        # forever; the user re-runs `nixos-rebuild switch` after fixing the key.
        Restart = "no";
      };

      # Inline script: wait for tailscaled, check state, conditionally up.
      script = ''
        set -eu

        # Give tailscaled a moment to settle (it's started just before us).
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1 && break
          sleep 1
        done

        state="$(${pkgs.tailscale}/bin/tailscale status -json 2>/dev/null \
                   | ${pkgs.jq}/bin/jq -r '.BackendState // "Unknown"')"

        case "$state" in
          Running)
            # "Running" against tailscale.com is NOT done: that host is still
            # on the old SaaS tailnet. Only skip if it is on OUR control server.
            ctrl="$(${pkgs.tailscale}/bin/tailscale debug prefs 2>/dev/null \
                      | ${pkgs.jq}/bin/jq -r '.ControlURL // ""')"
            if [ "$ctrl" = "${config.services.tailscale.loginServer}" ]; then
              echo "tailscale already running on $ctrl, nothing to do"
              exit 0
            fi
            echo "tailscale running on '$ctrl', moving to ${config.services.tailscale.loginServer}"
            ;;
          NeedsLogin|Stopped|NoState|Unknown)
            echo "tailscale state=$state, attempting auth-key login"
            ;;
          *)
            echo "tailscale state=$state, attempting auth-key login anyway"
            ;;
        esac

        key=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.tailscale-auth-key.path})
        if [ -z "$key" ] || [ "$key" = "REPLACE_WITH_REAL_KEY" ] || [ "''${key#tskey-}" != "$key" ]; then
          echo "tailscale-auth-key is empty or placeholder; refusing to call tailscale up" >&2
          exit 1
        fi

        # --auth-key=file: keeps the key out of argv / ps.
        ${pkgs.tailscale}/bin/tailscale up \
          --login-server=${config.services.tailscale.loginServer} \
          --auth-key=file:${config.sops.secrets.tailscale-auth-key.path} \
          --hostname=${config.services.tailscaleAutoconnect.hostname} \
          --accept-routes \
          --reset \
          --force-reauth
      '';
    };
  };
}
