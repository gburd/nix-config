{ self, inputs, outputs, stateVersion, ... }:
let
  sshMatrix = import ./ssh-matrix.nix { };
in
{
  # Helper function for generating home-manager configs.
  #
  # solnixReady gates the *-solaris path. solnix-pkgs cannot yet evaluate a
  # full home-manager closure (its solaris stdenv/pkg set is incomplete --
  # even a minimal HM config hits `attribute 'shellPath'` missing, and our
  # full module tree hits infinite recursion in the patched-nixpkgs lib).
  # While solnixReady=false, a -solaris host falls back to x86_64-linux pkgs
  # so the config still EVALUATES (profile shape; `nix flake check` stays
  # green). Flip it to true once solnix-pkgs can build a closure -- the
  # `nix run .#check-solnix-ready` (flake.nix) exits nonzero when that day
  # comes, prompting the flip. The solaris profile guards every install
  # `pkgs.foo or null` (systems/solaris.nix), so the fallback pkgs set never
  # drags in a wrong-arch closure.
  mkHome = { hostname, username, desktop ? null, platform ? "x86_64-linux", solnixReady ? false }: inputs.home-manager.lib.homeManagerConfiguration {
    pkgs =
      let isSolaris = builtins.match ".*-solaris" platform != null;
      in
      if isSolaris && solnixReady && (inputs ? solnix-pkgs)
      then
        import inputs.solnix-pkgs.lib.nixpkgsSrc
          {
            system = platform;
            overlays = [ inputs.solnix-pkgs.overlays.default ];
            config.allowUnsupportedSystem = true;
          }
      else inputs.nixpkgs.legacyPackages.${platform} or inputs.nixpkgs.legacyPackages.x86_64-linux;
    extraSpecialArgs = {
      inherit inputs outputs desktop hostname platform username stateVersion sshMatrix;
    };
    modules = [ ../home-manager ];
  };

  # mkSolnixHost -- the SYSTEM half of a solnix (Nix-on-illumos) host.
  #
  # ⚠️ WHY THIS IS NOT mkHost. mkHost is inputs.nixpkgs.lib.nixosSystem, which
  # builds a LINUX system: it pulls in systemd, an initrd, a bootloader and a
  # Linux kernel, none of which exist on illumos. mkHome gets away with a
  # *-solaris platform because home-manager only needs PACKAGES -- no kernel, no
  # init. A SYSTEM needs both, so it must go through solnix's OWN evaluator
  # (solnix/lib/eval-config.nix, the analog of nixos/lib/eval-config.nix), which
  # evaluates solnix's module tree (SMF instead of systemd, ZFS boot environments
  # instead of GRUB generations).
  #
  # The attrset these feed is called `solnixConfigurations` in flake.nix, not
  # `nixosConfigurations`, for the same reason -- and because solnix-install
  # already probes solnixConfigurations BEFORE nixosConfigurations, so
  # `solnix-install --flake .#dixi` resolves with no installer change.
  #
  # ⚠️ EVAL HERE, BUILD ON ILLUMOS. config.system.build.toplevel is an
  # x86_64-solaris derivation. It EVALUATES on this Linux box; it can only be
  # REALISED on an illumos host (the gate proto and the slices carved from it are
  # x86_64-solaris store paths). Do not read a successful `nix eval` as a build.
  mkSolnixHost = { hostname, modules ? [ ], platform ? "x86_64-solaris" }:
    let
      # The patched nixpkgs that knows about the *-solaris platforms. Same source
      # mkHome uses, for the same reason: stock nixpkgs has no *-solaris system.
      solnixNixpkgs = inputs.solnix-pkgs.lib.nixpkgsSrc;
      pkgs = import solnixNixpkgs {
        system = platform;
        # solnix-pkgs.overlays.default is only the BOOTSTRAP half of pkgs.solnix.
        # A toplevel also needs worldOverlay (wires pkgs.solnix.systemPath, read by
        # solnix's activation/default.nix) and shellPathOverlay (restores
        # bashNonInteractive.shellPath); without them dixi's drvPath throws
        # "attribute 'systemPath' missing" and solnix-install reports "no system
        # configuration names dixi". solnix exports both from its lib so we apply
        # the SAME layers its own pkgsFor does rather than drifting a copy.
        overlays = [
          inputs.solnix-pkgs.overlays.default
          inputs.solnix.lib.shellPathOverlay
          inputs.solnix.lib.worldOverlay
        ];
        config.allowUnsupportedSystem = true;
      };
    in
    inputs.solnix.lib.solnixSystem {
      system = platform;
      inherit pkgs;
      modules = [{ networking.hostName = hostname; }] ++ modules;
    };

  # Helper function for generating host configs
  # - installer: can be one of the following:
  #    - "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
  #    - "/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares.nix"
  mkHost = { hostname, username, systemType, desktop ? null, installer ? null }: inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs outputs desktop hostname username stateVersion systemType sshMatrix;
    };
    modules = [
      ../nixos
    ] ++ (inputs.nixpkgs.lib.optionals (installer != null) [ installer ]);
  };

  # NixOS running as a WSL2 distro. Same nixos/ tree as mkHost, plus the
  # nixos-wsl module (which provides the WSL boot/interop layer in place of
  # real hardware-configuration). systemType is fixed to "wsl" so the host
  # config lives under nixos/wsl/<hostname>/.
  mkWslHost = { hostname, username }: inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs outputs hostname username stateVersion sshMatrix;
      systemType = "wsl";
      desktop = null;
    };
    modules = [
      ../nixos
      inputs.nixos-wsl.nixosModules.default
    ];
  };

  mkDarwin = { hostname, username, stateVersion ? 4, platform ? "aarch64-darwin" }: inputs.nix-darwin.lib.darwinSystem {
    specialArgs = {
      inherit self inputs outputs hostname username platform stateVersion sshMatrix;
    };
    modules = [
      ../darwin
      inputs.home-manager.darwinModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        # First activation on a machine with pre-existing dotfiles: back up
        # clobbered files (~/.zshrc, ~/.gitconfig, ...) to *.hm-bak, don't error.
        home-manager.backupFileExtension = "hm-bak";
        # HM modules (e.g. programs.ai.skills, which reads
        # inputs.postgresq-skills-*) need the flake args too — darwin's
        # specialArgs only reach the system modules, not the nested HM
        # ones, so forward them explicitly here.
        home-manager.extraSpecialArgs = {
          inherit inputs outputs hostname username platform stateVersion sshMatrix;
          desktop = null;
        };
      }
    ];
  };

  mkSdImage = { hostname, username, platform ? "armv7l-linux" }: inputs.nixos-generators.nixosGenerate {
    specialArgs = {
      inherit self inputs outputs hostname username platform stateVersion sshMatrix;
    };

    pkgs = inputs.nixpkgs.legacyPackages.${platform};
    format =
      if platform == "armv7l-linux"
      then "sd-armv7l-installer"
      else "sd-aarch64-installer";

    modules = [
      ../nixos
    ];
  };

  mkRawImage = { hostname, username, systemType, desktop ? null, platform ? "x86_64-linux" }: inputs.nixos-generators.nixosGenerate {
    specialArgs = {
      inherit self inputs outputs desktop hostname username stateVersion systemType sshMatrix;
    };

    pkgs = inputs.nixpkgs.legacyPackages.${platform};
    format =
      if platform == "x86_64-linux"
      then "raw-efi"
      else "raw";

    modules = [
      ../nixos
      {
        boot.kernelParams = [ "console=tty0" ]; # enable physical display tty, not serial port
      }
    ];
  };

  forAllSystems = inputs.nixpkgs.lib.genAttrs [
    "armv7l-linux" # 32-bit ARM Linux
    "aarch64-linux" # 64-bit ARM Linux
    "i686-linux" # 32-bit x86 Linux
    "x86_64-linux" # 64-bit x86 Linux
    "aarch64-darwin" # 64-bit ARM Darwin
    "x86_64-darwin" # 64-bit x86 Darwin
  ];
}
