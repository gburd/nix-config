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
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    # You can access packages and modules from different nixpkgs revs at the
    # same time. See 'unstable-packages' overlay in 'overlays/default.nix'.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Chaotic's Nyx provides many additional packages like NordVPN

    nix-formatter-pack.url = "github:Gerschtli/nix-formatter-pack";
    nix-formatter-pack.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    vscode-server.url = "github:msteen/nixos-vscode-server";

    devshells.url = "github:gburd/devshells";
    devshells.inputs.nixpkgs.follows = "nixpkgs";

    # solnix-pkgs: illumos (x86_64-solaris / aarch64-solaris) support for Nix,
    # as an overlay + patch set over a pinned nixpkgs. Exposes lib.nixpkgsSrc
    # (the patched nixpkgs with the *-solaris platforms wired in) + overlays.
    # default -- consumed by mkHome (lib/helpers.nix) to give the dixi/dixa/dixr
    # solnix hosts a real solaris pkg set instead of the x86_64-linux fallback.
    solnix-pkgs.url = "git+https://codeberg.org/solnix/solnix-pkgs.git";

    # NOTE: solnix-pkgs.inputs.nixpkgs is deliberately NOT followed.
    #
    # It used to be `follows = "nixpkgs"`, and that SILENTLY BROKE every solaris
    # config in this flake -- including the homeConfigurations that predate the
    # dix system configs. Measured: with the follows, evaluating
    # homeConfigurations."gburd@dixi" fails while BUILDING
    # nixpkgs-solnix-patched, with
    #
    #   patching file lib/systems/parse.nix
    #   Hunk #2 FAILED at 876.  Hunk #3 FAILED at 949.
    #   2 out of 3 hunks FAILED -- saving rejects to lib/systems/parse.nix.rej
    #
    # solnix-pkgs adds the *-solaris platforms by PATCHING nixpkgs' lib/systems,
    # against its own pin (7f81d69). lib/systems/parse.nix has since moved, so
    # forcing nixos-26.05 in makes the patch fail to apply, the patched-nixpkgs
    # derivation fail to build, and every -solaris evaluation die -- as a BUILD
    # error, which reads like an unrelated infrastructure problem rather than an
    # input-pin mistake.
    #
    # The cost of not following is a second nixpkgs copy in the store. The cost of
    # following is that nothing solaris works at all. Let solnix-pkgs keep its pin.

    # solnix itself -- the illumos distribution: its module tree (SMF instead of
    # systemd, ZFS boot environments instead of GRUB generations) and its
    # evaluator lib.solnixSystem, which is the nixosSystem analog. Consumed by
    # mkSolnixHost (lib/helpers.nix) for solnixConfigurations.{dixi,dixa,dixr}.
    # Same reasoning as above: no nixpkgs follows.
    # ?ref=main is REQUIRED, not cosmetic: without it Nix resolves the default
    # branch as `master` and fails with
    #   error: resolving Git reference 'master': revspec 'master' not found
    # solnix's default branch is `main`. Measured on a fresh node with no
    # pre-populated flake registry -- it does NOT reproduce where the input is
    # already in the local eval cache, which is exactly why it survived to here.
    solnix.url = "git+https://codeberg.org/solnix/solnix.git?ref=main";

    # Darwin support with nix-darwin
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";

    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # NixOS-WSL: run NixOS as a WSL2 distro (santorini host).
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    # Colmena: declarative deploy/management of a fleet of NixOS hosts
    # (the EC2 perf-test instances).
    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";

    # PostgreSQL agent skills (https://codeberg.org/ddx/skills.git).
    # Single branch: skills are written once for every agent (Agent Skills Open
    # Standard). Collections: postgres/, tooling/, ai-life-skills/, plus shared
    # community/, generic/, examples/. Deployed by
    # modules/home-manager/ai/skills.nix as a blend over the in-tree operator
    # skills, not a replacement.
    postgresq-skills = {
      url = "git+https://codeberg.org/ddx/skills.git?ref=main";
      flake = false;
    };

    # ponytail — cross-agent "lazy senior dev" skill/ruleset (YAGNI). Ships
    # per-agent plugins, skills/, and a Pi extension; deployed to all agents
    # by modules/home-manager/ai/skills.nix. Pinned for reproducibility.
    ponytail = {
      url = "github:DietrichGebert/ponytail";
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

    # maki -- my fork of the maki coding agent, built by pkgs/maki.
    # PINNED to 6767244 (0.5.5, rust-version 1.88). The branch tip has moved
    # to 0.6.3 (e29d548), whose workspace Cargo.toml demands rust-version
    # 1.99, but our nixpkgs ships rustc 1.95 -- that version cannot compile.
    # Pinning the rev here (not just the lock) stops a bare `nix flake update`
    # or the lock-updater CI from dragging it forward again, which is what
    # broke the HM build (vendor-hash mismatch, then an MSRV wall behind it).
    # Lift the pin once nixpkgs-unstable carries rustc >= 1.99, bump to the
    # newest tag, and refresh pkgs/maki cargoHash. Not a flake itself;
    # consumed as a source tree, threaded in via pkgs/default.nix.
    maki-src = {
      url = "github:gburd/maki/429f03329f96ed677c79b0bb396dc2b3d7c5c123";
      flake = false;
    };

    impermanence.url = "github:nix-community/impermanence";
  };
  outputs =
    {
      self,
      nix-formatter-pack,
      nixpkgs,
      ...
    }@inputs:
    let
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = "25.11";

      inherit (self) outputs;
      sshMatrix = import ./lib/ssh-matrix.nix { };
      libx = import ./lib {
        inherit
          self
          inputs
          outputs
          stateVersion
          ;
      };

      # solnix-pkgs cannot yet evaluate a home-manager (or system) closure --
      # its *-solaris pkg set is incomplete. While false, the dixi/dixa/dixr
      # home configs fall back to x86_64-linux pkgs so they EVALUATE (profile
      # shape) and `nix flake check` stays green. Flip to true once solnix-pkgs
      # is ready; run `nix run .#check-solnix-ready` -- it exits nonzero (with
      # flip instructions) the moment solnix-pkgs can evaluate a closure,
      # prompting this flip + wiring the real solaris pkg set through.
      solnixReady = false;
    in
    {
      # home-manager switch -b backup --flake $HOME/ws/nix-config
      # nix build .#homeConfigurations."gburd@floki".activationPackage
      homeConfigurations = {
        # .iso images

        # Workstations
        "gburd@floki" = libx.mkHome {
          hostname = "floki";
          username = "gburd";
          desktop = "gnome";
        };
        "gburd@meh" = libx.mkHome {
          hostname = "meh";
          username = "gburd";
        }; # headless
        "gburd@arnold" = libx.mkHome {
          hostname = "arnold";
          username = "gburd";
        };
        # werk: headless x86_64 NixOS on EC2 (m6idn.12xlarge). See
        # home-manager/_mixins/users/gburd/hosts/werk.nix.
        "gburd@werk" = libx.mkHome {
          hostname = "werk";
          username = "gburd";
        }; # headless
        # lixr: LOCAL riscv64 (SpacemiT K3 Pico ITX, 192.168.1.179). Bianbu +
        # home-manager, like arnold; no `desktop` arg because Bianbu runs
        # LXQt/labwc, not GNOME. Built from source: no riscv64 binary cache.
        "gburd@lixr" = libx.mkHome {
          hostname = "lixr";
          username = "gburd";
          platform = "riscv64-linux";
        };
        # santorini: NixOS-WSL guest on the ARM64 Windows host. aarch64, headless.
        # Activate inside the distro: home-manager switch -b backup --flake .#"gburd@santorini"
        "gburd@santorini" = libx.mkHome {
          hostname = "santorini";
          username = "gburd";
          platform = "aarch64-linux";
        };
        # gburd@ec2: agent-sandbox's `--tier ec2` guest (see
        # modules/home-manager/ai/agent-sandbox.nix). NOT a real host --
        # deployed fresh via `nix run github:gburd/nix-config#homeConfigurations."gburd@ec2".activationPackage -- switch`
        # on a throwaway NixOS EC2 instance every time one is provisioned.
        # Headless like meh; hosts/ec2.nix keeps it deliberately minimal
        # (console/ai only, no sops/backups/desktop -- there's no secrets
        # file on a fresh box, and litellm.enable=false since agents
        # there reach the ORIGINATING host's gateway over an SSH tunnel).
        "gburd@ec2" = libx.mkHome {
          hostname = "ec2";
          username = "gburd";
        };

        # solnix (Nix on illumos/Solaris): platform <arch>-solaris ->
        # systemType "solaris" -> systems/solaris.nix. The illumos package set
        # comes from the solnix-pkgs fork (exposes the *-solaris platforms +
        # pkgs.illumos.*), NOT stock nixpkgs. But solnix-pkgs can't yet
        # evaluate a full HM closure, so mkHome gates it behind solnixReady
        # (currently false -> x86_64-linux fallback so these EVALUATE; profile
        # shape only, nothing builds). See solnixReady in the let block + the
        # `nix run .#check-solnix-ready`. Solnix arch roadmap: x86_64 = Phase 1, aarch64
        # = Phase 3, RISC-V = Phase 5 -- so dixa/dixr are staged targets ahead
        # of the fork supporting their platforms.
        #
        # Three "dix" hosts:
        #   * dixi -- x86_64, EC2, HEADLESS (no COSMIC). Also the solnix home on arnold and lixi.
        #     A small command-line profile on solnix's own package set
        #     (lib/helpers.nix mkSolnixHome, home-manager/solnix.nix), built on dixi.
        "gburd@dixi" = libx.mkSolnixHome {
          hostname = "dixi";
          username = "gburd";
        };
        #   * lixi -- x86_64 solnix on the ThinkPad X1 Extreme Gen 5 (solnixConfigurations.lixi's home half). Same
        #     command-line profile as dixi; built on lixi itself (system.buildCapable) or a solnix build host.
        "gburd@lixi" = libx.mkSolnixHome {
          hostname = "lixi";
          username = "gburd";
        };
        #   * dixa -- aarch64, EC2 (permanent account), HEADLESS (no COSMIC). Same profile on solnix's
        #     aarch64 set (pkgs/illumos/aarch64: no Rust or Go tier, neither has an illumos/aarch64 target).
        #     Built on dixa itself, through its nix-daemon.
        "gburd@dixa" = libx.mkSolnixHome {
          hostname = "dixa";
          username = "gburd";
          platform = "aarch64-solaris";
        };
        #   * dixr -- riscv64 hosted SERVER (likely qemu-system-riscv64 on EC2), HEADLESS, no GPU.
        "gburd@dixr" = libx.mkHome {
          hostname = "dixr";
          username = "gburd";
          platform = "riscv64-solaris";
          inherit solnixReady;
        };

        # Servers
      };

      # solnixConfigurations -- the SYSTEM half of the solnix (Nix-on-illumos)
      # hosts. The nixosConfigurations analog, and NOT part of it: see
      # lib/helpers.nix:mkSolnixHost for why mkHost/nixosSystem cannot build these
      # (it builds a Linux system -- systemd, initrd, GRUB, a Linux kernel).
      #
      # The name matters: solnix-install probes solnixConfigurations BEFORE
      # nixosConfigurations, so this is what makes the maintainer's requested
      #
      #   solnix-install --git https://github.com/gburd/nix-config.git \
      #                  --flake .#dixi --home-manager .#gburd@dixi
      #
      # resolve, with no change to the installer.
      #
      # WARNING: THESE EVALUATE HERE AND ONLY BUILD ON AN ILLUMOS HOST.
      # config.system.build.toplevel is an x86_64-solaris (or aarch64/riscv64)
      # derivation; the gate proto and the slices carved from it are *-solaris
      # store paths that cannot be realised on Linux. `nix eval` succeeding is not
      # a build, and a build is not a boot -- three separate claims, and this
      # campaign produced four bugs from blurring them.
      #
      # Per-host honesty is in each file, and is not uniform:
      #   dixi      -- x86_64 EC2, from the public DP AMI. Builds on illumos.
      #   dixa      -- aarch64 EC2. Reaches login on c6g.metal; an EL0 SError panic blocks sshd; no userland built.
      #   dixr      -- riscv64 hosted server (qemu virt on EC2), headless. Shell session works; no nix/ZFS yet.
      #   arnold    -- x86_64, ThinkPad X1 Extreme Gen 1 (was dixi). COSMIC is not a desktop.
      #   lixi      -- x86_64, ThinkPad X1 Extreme Gen 5. iwx bound; i915/nvidia shipped unbound.
      #   lixr      -- riscv64 Milk-V (SpacemiT K3, not K1). ASPIRATIONAL SCAFFOLDING ONLY.
      solnixConfigurations = {
        # dixi: x86_64 EC2 (the public DP AMI + this config).
        dixi = libx.mkSolnixHost {
          hostname = "dixi";
          platform = "x86_64-solaris";
          modules = [ ./nixos/solnix/dixi.nix ];
        };
        # dixa: aarch64 EC2.
        dixa = libx.mkSolnixHost {
          hostname = "dixa";
          platform = "aarch64-solaris";
          modules = [ ./nixos/solnix/dixa.nix ];
        };
        # dixr: riscv64 hosted server, headless (likely qemu-system-riscv64 on EC2).
        dixr = libx.mkSolnixHost {
          hostname = "dixr";
          platform = "riscv64-solaris";
          modules = [ ./nixos/solnix/dixr.nix ];
        };
        # arnold: ThinkPad X1 Extreme Gen 1 (was "dixi"). Also runs Fedora + gburd@arnold.
        arnold = libx.mkSolnixHost {
          hostname = "arnold";
          platform = "x86_64-solaris";
          modules = [ ./nixos/solnix/arnold.nix ];
        };
        # lixi: ThinkPad X1 Extreme Gen 5 (iwx wifi bound; GPUs shipped unbound).
        lixi = libx.mkSolnixHost {
          hostname = "lixi";
          platform = "x86_64-solaris";
          modules = [ ./nixos/solnix/lixi.nix ];
        };
        # lixi-gpu1: lixi + the i915 driver bound at boot (GPU stage B, stage 1 of src/drm-port/i915/STAGED-ATTACH-PLAN.md
        # in solnix). Only ever installed as a BOOT-ONCE BE (beadm activate -t) with the operator at the machine; the
        # default BE stays plain lixi. Nothing opens /dev/dri/card0 in it (no desktop), so no modeset runs.
        lixi-gpu1 = libx.mkSolnixHost {
          hostname = "lixi";
          platform = "x86_64-solaris";
          modules = [ ./nixos/solnix/lixi.nix ({ lib, ... }: { hardware.graphics.i915.attachAtBoot = lib.mkForce true; }) ];
        };
        # lixi-cosmic: lixi + the COSMIC desktop (cosmic-greeter under greetd on VT 7, seatd, the system bus).
        # Only ever installed as a BOOT-ONCE BE (beadm activate -t) while the graphical login is brought up; the
        # default BE stays plain lixi until it works on the panel.
        lixi-cosmic = libx.mkSolnixHost {
          hostname = "lixi";
          platform = "x86_64-solaris";
          modules = [ ./nixos/solnix/lixi.nix {
            services.desktopManager.cosmic.enable = true;
            users.users.gburd.extraGroups = [ "seat" ];   # may open the seat (seatd -g seat), as on NixOS
          } ];
        };
        # lixr: the Milk-V K3 board, riscv64 (was "dixr").
        lixr = libx.mkSolnixHost {
          hostname = "lixr";
          platform = "riscv64-solaris";
          modules = [ ./nixos/solnix/lixr.nix ];
        };
      };

      # Support for nix-darwin workstations. Single profile for this machine:
      # logical name "aws"; real (IT-assigned) hostname stays "80a99738d7e2".
      # - build:  nix build .#darwinConfigurations.aws.system
      # - switch: darwin-rebuild switch --flake .#aws
      darwinConfigurations = {
        aws = libx.mkDarwin {
          username = "gregburd";
          hostname = "aws";
          stateVersion = 4;
        };
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations.aws.pkgs;

      nixosConfigurations = {
        # .iso images
        #  - nix build .#nixosConfigurations.{iso-console|iso-desktop}.config.system.build.isoImage

        # Workstations
        # Lenovo Carbon X1 Extreme Gen 5 - x86_64
        floki = libx.mkHost {
          systemType = "workstation";
          hostname = "floki";
          username = "gburd";
          desktop = "gnome";
        };

        # Mac Pro "Trash Can" (Late 2013) - x86_64 - HEADLESS (terminal-only;
        # GPU compute via the AMD FirePro D700s is preserved via
        # nixos/_mixins/hardware/gpu-compute.nix imported from the host).
        meh = libx.mkHost {
          systemType = "workstation";
          hostname = "meh";
          username = "gburd";
        };

        # NixOS as a WSL2 distro on the Windows host "santorini".
        # Inside the distro: sudo nixos-rebuild switch --flake ~/ws/nix-config#santorini
        santorini = libx.mkWslHost {
          hostname = "santorini";
          username = "gburd";
        };

        # Servers
        # Can be executed locally:
        #  - sudo nixos-rebuild switch --flake $HOME/ws/nix-config
        #
        # Or remotely:
        #  - nixos-rebuild switch --fast --flake .#${HOST} \
        #      --target-host ${USERNAME}@${HOST}.${TAILNET} \
        #      --build-host  ${USERNAME}@${HOST}.${TAILNET}

        # EC2 PostgreSQL performance-test hosts (managed via Colmena; AMIs
        # built with `nixos-rebuild build-image --image-variant amazon`).
        pgperf-arm = libx.mkHost {
          systemType = "server";
          hostname = "pgperf-arm";
          username = "gburd";
        };
        pgperf-x86 = libx.mkHost {
          systemType = "server";
          hostname = "pgperf-x86";
          username = "gburd";
        };

        # werk: x86_64 NixOS on EC2 (m6idn.12xlarge), HEADLESS. A headless
        # floki -- same nixos/ tree, no desktop, amazon-image boot layer, and
        # an instance-store NVMe RAID0 stripe for /home + /scratch. See
        # nixos/server/werk/default.nix. On our Headscale via
        # tailscale-autoconnect (werk's age key is enrolled in .sops.yaml).
        werk = libx.mkHost {
          systemType = "server";
          hostname = "werk";
          username = "gburd";
        };

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
            inherit
              inputs
              outputs
              stateVersion
              sshMatrix
              ;
            desktop = null;
            username = "gburd";
          };
        };

        pgperf-arm = { ... }: {
          deployment = {
            targetHost = "pgperf-arm"; # set to the live instance addr/Tailscale name
            targetUser = "root";
            tags = [
              "perf"
              "db"
              "arm"
            ];
          };
          imports = [ ./nixos ];
          _module.args = {
            hostname = "pgperf-arm";
            systemType = "server";
          };
        };

        pgperf-x86 = { ... }: {
          deployment = {
            targetHost = "pgperf-x86";
            targetUser = "root";
            tags = [
              "perf"
              "db"
              "x86"
            ];
          };
          imports = [ ./nixos ];
          _module.args = {
            hostname = "pgperf-x86";
            systemType = "server";
          };
        };
      };

      # nixOnDroidConfigurations removed along with the nix-on-droid input
      # (was never wired into outputs; release-23.11 dragged in a stale
      # nixpkgs + home-manager chain).

      # Devshell for bootstrapping; accessible via 'nix develop' or 'nix-shell' (legacy)
      devShells = libx.forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./shell.nix { inherit pkgs; }
      );

      # nix fmt
      formatter = libx.forAllSystems (
        system:
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

      # `nix run .#check-solnix-ready` -- the TRIGGER that tells us when to undo
      # the solnixReady=false workaround. It asks "can solnix-pkgs evaluate a
      # home-manager closure on x86_64-solaris yet?" and inverts the answer:
      #   * probe FAILS (solnix still incomplete) -> exits 0, "nothing to do".
      #   * probe SUCCEEDS (closure-ready)        -> exits 1 with the flip
      #     instructions (set solnixReady=true, drop the guard).
      #
      # It's an APP, not a flake `check`, on purpose: the probe needs
      # `builtins.getFlake` on our own tree, which the `nix flake check`
      # sandbox cannot do (fchmodat2 EPERM on the copied source) -- and this
      # Nix's builtins.tryEval does NOT catch the `attribute 'shellPath'
      # missing` / infinite-recursion class the incomplete solaris pkg set
      # raises, so an in-eval check would crash `nix flake check` itself. An
      # app runs unsandboxed where getFlake works. Run it by hand, or from a
      # periodic job, when you want to know if solnix-pkgs caught up.
      # ponytail: no automated CI gate here -- the sandbox can't run the probe;
      # a manual `nix run` is the honest minimum that doesn't lie or crash CI.
      apps = libx.forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          script = pkgs.writeShellApplication {
            name = "check-solnix-ready";
            runtimeInputs = [ pkgs.nix ];
            text = ''
              if nix eval --impure --expr '
                    let i = (builtins.getFlake (toString ${self})).inputs;
                        p = import i.solnix-pkgs.lib.nixpkgsSrc {
                          system = "x86_64-solaris";
                          overlays = [ i.solnix-pkgs.overlays.default ];
                          config.allowUnsupportedSystem = true;
                        };
                        hm = i.home-manager.lib.homeManagerConfiguration {
                          pkgs = p;
                          modules = [{ home.username = "probe"; home.homeDirectory = "/home/probe"; home.stateVersion = "${stateVersion}"; }];
                        };
                    in builtins.seq hm.activationPackage.drvPath true' >/dev/null 2>&1; then
                echo "solnix-pkgs CAN now evaluate a home-manager closure on x86_64-solaris."
                echo "ACTION: set solnixReady = true in flake.nix's let block, wire the real"
                echo "        solaris pkg set through, and delete this trigger."
                exit 1
              else
                echo "solnix-pkgs still cannot evaluate a HM closure; solnixReady=false is correct."
                exit 0
              fi
            '';
          };
        in
        {
          check-solnix-ready = {
            type = "app";
            program = "${script}/bin/check-solnix-ready";
          };
        }
      );

      # Custom packages; acessible via 'nix build', 'nix shell', etc
      packages = libx.forAllSystems (
        system:
        let
          # allowUnfree so unfree custom pkgs (e.g. kiro-cli) evaluate —
          # otherwise `nix flake check` fails on packages.<sys>.kiro-cli
          # with "has an unfree license, refusing to evaluate".
          # unstable-packages overlay provides `pkgs.unstable`, which
          # pkgs/default.nix needs for maki's rustPlatform (1.95).
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ outputs.overlays.unstable-packages ];
          };
        in
        (import ./pkgs { inherit pkgs inputs; })
        // {
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
