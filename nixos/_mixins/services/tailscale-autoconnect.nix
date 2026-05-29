{ config, pkgs, ... }:
{
  imports = [ ./tailscale.nix ];

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
  #   1. https://login.tailscale.com/admin/settings/keys → Generate
  #      auth key. Pick "Reusable" + tag with the host's name. Copy
  #      the `tskey-auth-...` value.
  #   2. `sops nixos/_mixins/secrets.yaml` → add or replace
  #         tailscale-auth-key: tskey-auth-XXXXXXXXXXXX...
  #   3. `sudo nixos-rebuild switch --flake .#<host>`
  #
  # If the secret is missing the activation will fail loudly. To opt
  # back to manual `tailscale up`, drop this import and import
  # ./tailscale.nix directly.
  # ---------------------------------------------------------------

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
          echo "tailscale already running, nothing to do"
          exit 0
          ;;
        NeedsLogin|Stopped|NoState|Unknown)
          echo "tailscale state=$state, attempting auth-key login"
          ;;
        *)
          echo "tailscale state=$state, attempting auth-key login anyway"
          ;;
      esac

      key=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.tailscale-auth-key.path})
      if [ -z "$key" ] || [ "$key" = "REPLACE_WITH_REAL_KEY" ]; then
        echo "tailscale-auth-key is empty or placeholder; refusing to call tailscale up" >&2
        exit 1
      fi

      ${pkgs.tailscale}/bin/tailscale up \
        --auth-key="$key" \
        --accept-routes \
        --reset
    '';
  };
}
