{
  description = "Greg Burd's NixOS and Home Manager Configuration";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    # You can access packages and modules from different nixpkgs revs at the
    # same time. See 'unstable-packages' overlay in 'overlays/default.nix'.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-trunk.url = "github:nixos/nixpkgs/master";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Chaotic's Nyx provides many additional packages like NordVPN
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    chaotic.inputs.nixpkgs.follows = "nixpkgs";

    nix-formatter-pack.url = "github:Gerschtli/nix-formatter-pack";
    nix-formatter-pack.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    vscode-server.url = "github:msteen/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";

    devshells.url = "github:gburd/devshells";
    devshells.inputs.nixpkgs.follows = "nixpkgs";

    # Darwin support with nix-darwin
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # nixos-generators for sdcard and raw disk install generation.
    # Upstream nix-community (the tcarrio fork was ~930d stale; upstream is
    # actively maintained and provides the same nixosGenerate interface).
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs-unstable";

    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # NixOS-WSL: run NixOS as a WSL2 distro (santorini host).
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    # Colmena: declarative deploy/management of a fleet of NixOS hosts
    # (the EC2 perf-test instances).
    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";

    # PostgreSQL community agent skills (https://codeberg.org/ddx/skills.git).
    # One input per agent branch — content overlaps but each branch ships its
    # own per-agent extras (claude/, pi/, kiro/, codex/, maki/ subdirs).
    # Deployed by modules/home-manager/ai/skills.nix as a blend over the
    # in-tree operator skills, not a replacement.
    postgresq-skills-claude = {
      url = "git+https://codeberg.org/ddx/skills.git?ref=claude";
      flake = false;
    };
    postgresq-skills-pi = {
      url = "git+https://codeberg.org/ddx/skills.git?ref=pi";
      flake = false;
    };
    postgresq-skills-kiro = {
      url = "git+https://codeberg.org/ddx/skills.git?ref=kiro";
      flake = false;
    };
    postgresq-skills-codex = {
      url = "git+https://codeberg.org/ddx/skills.git?ref=codex";
      flake = false;
    };
    postgresq-skills-maki = {
      url = "git+https://codeberg.org/ddx/skills.git?ref=maki";
      flake = false;
    };

    # ponytail — cross-agent "lazy senior dev" skill/ruleset (YAGNI). Ships
    # per-agent plugins, skills/, and a Pi extension; deployed to all agents
    # by modules/home-manager/ai/skills.nix. Pinned for reproducibility.
    ponytail = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };

    # NVIDIA SkillSpector — static+LLM security scanner for agent skills.
    # Run in --no-llm static mode at home-manager switch to gate skill
    # installation (exit 1 => fail the switch). Python (flake-packaged).
    skillspector = {
      url = "github:NVIDIA/SkillSpector";
      flake = false;
    };

    # superpowers (obra/superpowers) — cross-agent spec/plan/TDD/subagent
    # methodology, MIT-licensed, listed on Anthropic's official Claude Code
    # plugin marketplace. We deploy only a CURATED SUBSET (see
    # skills.superpowers in skills.nix) -- the 4 skills covering structured
    # spec-writing, plan-writing, red/green TDD enforcement, and parallel
    # subagent dispatch that weren't already covered by our own
    # brainstorming/checkpoint/subagent-teams skills -- not the whole
    # opinionated methodology (which assumes docs/superpowers/ paths, its
    # own plan-file conventions, etc. that would collide with our existing
    # workflow). Pinned for reproducibility, same as ponytail above.
    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };

    # treehouse (Kun Chen) — reusable git-worktree pool for parallel agents
    # (worktrees preserved with deps + build cache intact). Go program with
    # a proper flake exposing packages.default.
    treehouse = {
      url = "github:kunchenguid/treehouse";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # no-mistakes (Kun Chen) — git push-proxy that validates changes via an
    # AI pipeline and opens a clean PR. Go module (no upstream flake), built
    # via buildGoModule in modules/home-manager/ai/kun-tools.nix.
    no-mistakes = {
      url = "github:kunchenguid/no-mistakes";
      flake = false;
    };

    # TODO... review below here
    impermanence.url = "github:nix-community/impermanence";

    #nh.url = "github:viperml/nh";
    #nh.inputs.nixpkgs.follows = "nixpkgs";

    #firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    #firefox-addons.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    { self
    , nix-formatter-pack
    , nixpkgs
    , ...
    } @ inputs:
    let
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = "25.11";

      inherit (self) outputs;
      sshMatrix = import ./lib/ssh-matrix.nix { };
      libx = import ./lib { inherit self inputs outputs stateVersion; };
    in
    {
      # home-manager switch -b backup --flake $HOME/ws/nix-config
      # nix build .#homeConfigurations."gburd@floki".activationPackage
      homeConfigurations = {
        # .iso images

        # Workstations
        "gburd@floki" = libx.mkHome { hostname = "floki"; username = "gburd"; desktop = "gnome"; };
        "gburd@meh" = libx.mkHome { hostname = "meh"; username = "gburd"; }; # headless
        "gburd@arnold" = libx.mkHome { hostname = "arnold"; username = "gburd"; };
        # gburd@ec2: agent-sandbox's `--tier ec2` guest (see
        # modules/home-manager/ai/agent-sandbox.nix). NOT a real host --
        # deployed fresh via `nix run github:gburd/nix-config#homeConfigurations."gburd@ec2".activationPackage -- switch`
        # on a throwaway NixOS EC2 instance every time one is provisioned.
        # Headless like meh; hosts/ec2.nix keeps it deliberately minimal
        # (console/ai only, no sops/backups/desktop -- there's no secrets
        # file on a fresh box, and litellm.enable=false since agents
        # there reach the ORIGINATING host's gateway over an SSH tunnel).
        "gburd@ec2" = libx.mkHome { hostname = "ec2"; username = "gburd"; };

        # Servers
      };

      # Support for nix-darwin workstations
      # - darwin-rebuild build --flake .#80a99738d7e2
      darwinConfigurations = {
        "80a99738d7e2" = libx.mkDarwin { username = "gregburd"; hostname = "80a99738d7e2"; stateVersion = 4; };
        # Work-issued macOS laptop (host named "aws"). Starting point matching
        # the other hosts; an agent on the host will tune it further.
        # - darwin-rebuild switch --flake .#aws
        aws = libx.mkDarwin { username = "gregburd"; hostname = "aws"; stateVersion = 4; };
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."80a99738d7e2".pkgs;

      nixosConfigurations = {
        # .iso images
        #  - nix build .#nixosConfigurations.{iso-console|iso-desktop}.config.system.build.isoImage

        # Workstations
        # Lenovo Carbon X1 Extreme Gen 5 - x86_64
        floki = libx.mkHost { systemType = "workstation"; hostname = "floki"; username = "gburd"; desktop = "gnome"; };

        # Mac Pro "Trash Can" (Late 2013) - x86_64 - HEADLESS (terminal-only;
        # GPU compute via the AMD FirePro D700s is preserved via
        # nixos/_mixins/hardware/gpu-compute.nix imported from the host).
        meh = libx.mkHost { systemType = "workstation"; hostname = "meh"; username = "gburd"; };

        # NixOS as a WSL2 distro on the Windows host "santorini".
        # Inside the distro: sudo nixos-rebuild switch --flake ~/ws/nix-config#santorini
        santorini = libx.mkWslHost { hostname = "santorini"; username = "gburd"; };

        # Servers
        # Can be executed locally:
        #  - sudo nixos-rebuild switch --flake $HOME/ws/nix-config
        #
        # Or remotely:
        #  - nixos-rebuild switch --fast --flake .#${HOST} \
        #      --target-host ${USERNAME}@${HOST}.${TAILNET} \
        #      --build-host  ${USERNAME}@${HOST}.${TAILNET}

        # EC2 PostgreSQL performance-test hosts (managed via Colmena; AMIs
        # built via packages.<platform>.ec2-pgperf-{arm,x86} below).
        pgperf-arm = libx.mkHost { systemType = "server"; hostname = "pgperf-arm"; username = "gburd"; };
        pgperf-x86 = libx.mkHost { systemType = "server"; hostname = "pgperf-x86"; username = "gburd"; };

        # agent-vm: minimal guest for agent-sandbox's microvm tier (strongest
        # isolation). Built once; booted per-invocation by agent-sandbox with
        # a dynamic project + command mount. Not a real host.
        agent-vm = inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./nixos/vm/agent-vm ];
        };
      };

      # Colmena: declarative fleet deploy for the EC2 perf-test hosts.
      #   colmena apply --on @perf            # deploy all perf hosts
      #   colmena apply switch --on pgperf-arm # one host
      # Reuses the same nixos/ modules as nixosConfigurations. Set each
      # node's deployment.targetHost to the instance's address (Tailscale
      # name or public DNS) once the AMIs are launched.
      colmenaHive = inputs.colmena.lib.makeHive {
        meta = {
          nixpkgs = import nixpkgs { system = "x86_64-linux"; };
          # aarch64 node needs its own pkgs (Graviton).
          nodeNixpkgs = {
            pgperf-arm = import nixpkgs { system = "aarch64-linux"; };
          };
          specialArgs = {
            inherit inputs outputs stateVersion sshMatrix;
            desktop = null;
            username = "gburd";
          };
        };

        pgperf-arm = { ... }: {
          deployment = {
            targetHost = "pgperf-arm"; # set to the live instance addr/Tailscale name
            targetUser = "root";
            tags = [ "perf" "db" "arm" ];
          };
          imports = [ ./nixos ];
          _module.args = { hostname = "pgperf-arm"; systemType = "server"; };
        };

        pgperf-x86 = { ... }: {
          deployment = {
            targetHost = "pgperf-x86";
            targetUser = "root";
            tags = [ "perf" "db" "x86" ];
          };
          imports = [ ./nixos ];
          _module.args = { hostname = "pgperf-x86"; systemType = "server"; };
        };
      };

      # nixOnDroidConfigurations removed along with the nix-on-droid input
      # (was never wired into outputs; release-23.11 dragged in a stale
      # nixpkgs + home-manager chain).

      # Devshell for bootstrapping; acessible via 'nix develop' or 'nix-shell' (legacy)
      #inherit (devshells) devShells;
      devShells = libx.forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./shell.nix { inherit pkgs; }
      );

      # nix fmt
      formatter = libx.forAllSystems (system:
        nix-formatter-pack.lib.mkFormatter {
          pkgs = nixpkgs.legacyPackages.${system};
          config.tools = {
            alejandra.enable = false;
            deadnix.enable = true;
            nixpkgs-fmt.enable = true;
            statix.enable = true;
          };
        }
      );

      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };

      # Custom packages; acessible via 'nix build', 'nix shell', etc
      packages = libx.forAllSystems
        (system:
          let
            # allowUnfree so unfree custom pkgs (e.g. kiro-cli) evaluate —
            # otherwise `nix flake check` fails on packages.<sys>.kiro-cli
            # with "has an unfree license, refusing to evaluate".
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          in
          (import ./pkgs { inherit pkgs; })
          //
          {
            # nuc-init = mkNuc "nixos"  "nuc-init";
            # system-image-nuc0 = mkNuc "archon" "nuc0";
            # system-image-nuc1 = mkNuc "archon" "nuc1";
            # system-image-nuc2 = mkNuc "archon" "nuc2";
            # system-image-nuc3 = mkNuc "archon" "nuc3";
            # system-image-nuc4 = mkNuc "archon" "nuc4";
            # system-image-nuc5 = mkNuc "archon" "nuc5";
            # system-image-nuc6 = mkNuc "archon" "nuc6";
            # system-image-nuc7 = mkNuc "archon" "nuc7";
            # system-image-nuc8 = mkNuc "archon" "nuc8";
            # system-image-nuc9 = mkNuc "archon" "nuc9";
          }
        );

      #      homeManagerModules = import ./modules/home-manager;
    };
}
