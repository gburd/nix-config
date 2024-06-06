{
  description = "Greg Burd's NixOS and Home Manager Configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    # You can access packages and modules from different nixpkgs revs at the
    # same time. See 'unstable-packages' overlay in 'overlays/default.nix'.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-trunk.url = "github:nixos/nixpkgs/master";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Chaotic's Nyx provides many additional packages like NordVPN
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    chaotic.inputs.nixpkgs.follows = "nixpkgs";

    nix-doom-emacs.url = "github:nix-community/nix-doom-emacs";
    nix-doom-emacs.inputs.nixpkgs.follows = "nixpkgs-unstable";

    nix-formatter-pack.url = "github:Gerschtli/nix-formatter-pack";
    nix-formatter-pack.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    vscode-server.url = "github:msteen/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";

    devshells.url = "github:gburd/devshells";
    devshells.inputs.nixpkgs.follows = "nixpkgs";

    # Android support with nix-on-droid. Currently not updated for 24.05
    nix-on-droid.url = "github:nix-community/nix-on-droid/release-23.05";
    nix-on-droid.inputs.nixpkgs.follows = "nixpkgs";

    # Darwin support with nix-darwin
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # nixos-generators for sdcard and raw disk install generation
    nixos-generators.url = "github:tcarrio/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs-unstable";

    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";

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
      stateVersion = "24.05";

      inherit (self) outputs;
      libx = import ./lib { inherit self inputs outputs stateVersion; };
    in
    {
      # home-manager switch -b backup --flake $HOME/ws/nix-config
      # nix build .#homeConfigurations."gburd@floki".activationPackage
      homeConfigurations = {
        # .iso images

        # Workstations
        "gburd@floki" = libx.mkHome { hostname = "floki"; username = "gburd"; desktop = "gnome"; };

        # Servers
      };

      # Support for nix-darwin workstations
      # - darwin-rebuild build --flake .#sktc0
      # darwinConfigurations = {
      #   "antanes" = libx.mkDarwin { username = "gburd"; hostname = "antanes"; stateVersion = 4; };
      # };

      # Expose the package set, including overlays, for convenience.
      # darwinPackages = self.darwinConfigurations."antanes".pkgs;

      nixosConfigurations = {
        # .iso images
        #  - nix build .#nixosConfigurations.{iso-console|iso-desktop}.config.system.build.isoImage

        # Workstations
        # Lenovo Carbon X1 Extreme Gen 5 - x86_64
        floki = libx.mkHost { systemType = "workstation"; hostname = "floki"; username = "gburd"; desktop = "gnome"; };

        # Servers
        # Can be executed locally:
        #  - sudo nixos-rebuild switch --flake $HOME/ws/nix-config
        #
        # Or remotely:
        #  - nixos-rebuild switch --fast --flake .#${HOST} \
        #      --target-host ${USERNAME}@${HOST}.${TAILNET} \
        #      --build-host  ${USERNAME}@${HOST}.${TAILNET}
      };

      # nixOnDroidConfigurations = {
      #   pixel6a-legacy = nix-on-droid.lib.nixOnDroidConfiguration {
      #     modules = [ ./android/pixel6a/config.nix ];
      #   };
      #   pixel6a = libx.mkDroid { hostname = "pixel6a"; username = "gburd"; };
      # };

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
            pkgs = nixpkgs.legacyPackages.${system};
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
