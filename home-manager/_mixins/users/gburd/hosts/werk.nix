{ inputs, pkgs, config, ... }:
# werk -- headless x86_64 NixOS on EC2 (m6idn.12xlarge). The home-manager half
# of the primary development workhorse. Modeled on meh.nix (the headless
# workstation profile): AI tooling, borgmatic backup, Proton mail bridge,
# vdirsyncer/khal calendars, SSH key rotation, and the unison sync mesh.
#
# Differences from meh, all because werk is a headless EC2 box:
#   * no GUI apps (1Password-gui, element-desktop) -- can't run headless. The
#     headless 1Password CLI (`op`, _1password-cli) IS shipped, for
#     ssh-management's sync1Password helpers.
#   * secrets live in nixos/workstation/werk/secrets.yaml (werk host age key +
#     gburd-user), copied from floki's real credentials; werk's OWN freshly
#     generated ssh auth/signing keys replace floki's there.
#
# EPHEMERAL /home WARNING: werk's /home and /scratch are an instance-store
# NVMe RAID0 that comes back BLANK after an EC2 stop or host-move (see
# nixos/server/werk/default.nix). So ~/.ssh/id_ed25519 (the key that unlocks
# HM sops), the Proton bridge keyring and vdirsyncer state are all lost on a
# stop and must be re-bootstrapped (copy id_ed25519 back by hand; the bridge
# re-logs-in from sops creds; vdirsyncer re-fetches from remote). borgmatic is
# the safety net for anything on the stripe not in git.
{
  imports = [
    ../../../console/ai # Opt-in AI configuration (LiteLLM gateway, MCPs, agents)
    ../../../services/borgmatic.nix
    # Email and productivity services (CLI / daemon)
    ../../../services/protonmail-bridge.nix
    ../../../services/vdirsyncer.nix
    ../../../console/khal.nix
    ../../../services/unison-sync.nix
    ../../../services/unison-ws-repos.nix
    ../../../console/hub.nix
    # SSH key management with rotation
    (inputs.self + "/modules/home-manager/ssh-management")
  ];

  # werk has no local aarch64 builder; cross-building the agent-sandbox Arm EC2
  # template on x86_64 fails without emulation. (werk's SYSTEM config does
  # enable aarch64 binfmt, so this could be flipped to true for slow emulated
  # builds; left off until that's actually wanted.)
  programs.ai.sandbox.ec2.buildAarch64 = false;

  # Live sync of project dirs + agent session state across hosts. werk joins
  # the nix-config mesh (floki/meh/arnold/werk). See services/unison-sync.nix
  # for what is and isn't synced, and the git caveat. NB werk's ~/ws is on the
  # ephemeral stripe, so a cold stripe re-seeds from the peers on first sync.
  programs.ai.sync = {
    enable = true;
    host = "werk";
    directories = [
      {
        name = "nix-config";
        path = "~/ws/nix-config";
        hosts = [ "floki" "meh" "arnold" "werk" ];
        # sessionRoots (default true): its pi/claude sessions travel with it
      }
      {
        # ~/src: project checkouts shared with floki/arnold. werk seeds from
        # floki's union on first sync. NB werk's ~/src is on the ephemeral
        # instance-store stripe, so a cold stripe re-seeds from the peers.
        name = "src";
        path = "~/src";
        hosts = [ "floki" "werk" "arnold" "meh" ];
        sessionRoots = false;
        ignores = [ "documentdb" "tre" ];
      }
      {
        # ~/ws tree -- mirror of floki/arnold's entry. werk joins AFTER
        # floki<->arnold has converged. Before switching werk into this,
        # move werk's own ~/ws aside to ~/_ws_ so werk's tree starts EMPTY
        # and seeds cleanly from the converged peers (an empty replica only
        # receives; it can't propagate a stale deletion). Rescue anything
        # unique from ~/_ws_ afterward.
        name = "ws";
        path = "~/ws";
        hosts = [ "floki" "arnold" "werk" "meh" ];
        sessionRoots = false;
        ignores = [
          "improv"
          "improv-libc"
          "libdb"
          "libxtc"
          "mentat"
          "nix-config"
          "osv"
          "pg_tre"
          "pg_tre-announce"
          "pg_weave"
          "ra"
          "solnix"
          "postgres"
        ];
      }
    ];
    sessionTrees = [
      {
        path = "~/src";
        hosts = [ "floki" "werk" "arnold" "meh" ];
        exclude = [ "documentdb" "tre" ];
      }
      {
        path = "~/ws";
        hosts = [ "floki" "arnold" "werk" "meh" ];
        exclude = [
          "improv"
          "improv-libc"
          "libdb"
          "libxtc"
          "mentat"
          "nix-config"
          "osv"
          "pg_tre"
          "pg_tre-announce"
          "pg_weave"
          "ra"
          "solnix"
          "postgres"
        ];
      }
    ];
  };

  # Sops secrets (werk's own file: werk host key + gburd-user). Decrypted with
  # the gburd-user age key derived from ~/.ssh/id_ed25519 (the same key meh/
  # floki use for HM sops).
  # Shared agent memory: every agent here talks to the one service on meh.
  # A switch here pushes the Cedar policy set to cedar-store on meh.
  programs.ai.cedarPush = {
    enable = true;
    tokenFile = config.sops.secrets."cedar-store/token".path;
  };

  programs.ai.mcps.servers.agent-memory = {
    enable = true;
    keyFile = config.sops.secrets."agent-memory/api-key".path;
  };

  sops = {
    defaultSopsFile = "${inputs.self}/nixos/workstation/werk/secrets.yaml";
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    secrets = {
      # Shared agent memory API key (mcp-memory-service on meh).
      "agent-memory/api-key" = { };
      "cedar-store/token" = { };
      # AWS Bedrock bearer token -> litellm proxy (without this litellm won't
      # start; it's the reason the first HM switch left the proxy inactive).
      "aws/bearer_token_bedrock" = {
        path = "${config.home.homeDirectory}/.config/claude-code/.bearer_token";
      };
      # Crates.io token (console/cargo.nix exposes it as $CARGO_REGISTRY_TOKEN).
      "cargo/crates_io_token" = { };

      # SSH key management: werk's OWN auth + signing private keys.
      "ssh-keys/auth" = {
        path = "${config.home.homeDirectory}/.ssh/id_auth_ed25519";
      };
      "ssh-keys/signing" = {
        path = "${config.home.homeDirectory}/.ssh/id_signing_ed25519";
      };

      # Borg backup passphrase, repo keyfile, and the rsync.net ssh key.
      "backup/borg-passphrase" = {
        path = "${config.home.homeDirectory}/.config/borgmatic/.passphrase";
      };
      "backup/rsync-ssh-key" = {
        path = "${config.home.homeDirectory}/.config/borgmatic/.rsync-key";
        mode = "0600";
      };
      "backup/borg-keyfile" = {
        path = "${config.home.homeDirectory}/.config/borg/keys/zh6216_rsync_net__borg";
        mode = "0600";
      };

      # Email account credentials (used by the Proton bridge + neomutt).
      "email/proton/user" = { };
      "email/proton/pass" = { };
      "email/proton/from" = { };
      "email/google/personal/user" = { };
      "email/google/personal/pass" = { };
      "email/apple/icloud/user" = { };
      "email/apple/icloud/pass" = { };

      # Calendar credentials (vdirsyncer/khal). Full set the vdirsyncer module
      # references (google personal + pgus, ms outlook, apple icloud).
      "calendar/google/personal/client-id" = { };
      "calendar/google/personal/secret" = { };
      "calendar/google/pgus/client-id" = { };
      "calendar/google/pgus/secret" = { };
      "calendar/ms/outlook/user" = { };
      "calendar/ms/outlook/pass" = { };
      "calendar/apple/icloud/user" = { };
      "calendar/apple/icloud/pass" = { };

      # Codeberg PAT for the tea CLI.
      "codeberg/tea_token" = { };
    };
  };

  # SSH key management with rotation. werk's OWN keys (generated on werk, the
  # privates in werk's secrets.yaml, the publics inline here).
  services.ssh-management = {
    enable = true;

    authKey = {
      secret = config.sops.secrets."ssh-keys/auth".path;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAFRiiiGWKBUlGyv4Zkv/H+58UJSs6r4CEEQEAqUBxQ5 greg@burd.me-auth-werk-202610";
    };

    signingKey = {
      secret = config.sops.secrets."ssh-keys/signing".path;
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDOPMXf1ibDys1YXLStPfqWpuCio2y87LW0eXTZYT3SG greg@burd.me-signing-werk-202610";
    };

    rotationInterval = "quarterly";
    sync1Password = true;
    gitHostingServices = [ "github" "codeberg" ];
  };

  home.packages = with pkgs; [
    # Shared CLI/dev packages come from users/gburd/default.nix + console.
    # Below: werk-specific. No GUI apps (headless); _1password-cli gives the
    # `op` CLI that ssh-management's sync1Password uses.
    _1password-cli
    cmake
    plocate
    unstable.rclone # S3/object-store client (minio-client replacement)
    awscli2 # S3/object-store CLI alongside rclone
  ];
}
