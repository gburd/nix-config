{ self, inputs, outputs, stateVersion, ... }:
let
  sshMatrix = import ./ssh-matrix.nix { };
in
{
  # Helper function for generating home-manager configs
  mkHome = { hostname, username, desktop ? null, platform ? "x86_64-linux" }: inputs.home-manager.lib.homeManagerConfiguration {
    # Resolve pkgs for the target platform. Stock nixpkgs has no *-solaris
    # systems (the solnix illumos platforms come from the solnix-pkgs fork,
    # not yet wired here), so a direct legacyPackages.<platform> lookup would
    # throw at eval and break `nix flake check`. Fall back to the host's
    # native pkgs when the platform is absent -- the config still evaluates
    # (proving the profile SHAPE) and gets a real solaris pkg set only once
    # solnix-pkgs is wired in. Everything the solaris profile actually
    # installs is guarded `pkgs.foo or null` (see systems/solaris.nix), so a
    # fallback pkgs set never pulls in a wrong-arch closure.
    pkgs =
      if inputs.nixpkgs.legacyPackages ? ${platform}
      then inputs.nixpkgs.legacyPackages.${platform}
      else inputs.nixpkgs.legacyPackages.x86_64-linux;
    extraSpecialArgs = {
      inherit inputs outputs desktop hostname platform username stateVersion sshMatrix;
    };
    modules = [ ../home-manager ];
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
