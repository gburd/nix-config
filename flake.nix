{
  description = "My (Greg Burd's) NixOS configuration";

   inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    hardware.url = "github:nixos/nixos-hardware";
    impermanence.url = "github:nix-community/impermanence";
    nix-colors.url = "github:misterio77/nix-colors";

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nh = {
      url = "github:viperml/nh";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-22_11.follows = "nixpkgs";
      inputs.nixpkgs-23_05.follows = "nixpkgs";
    };
    firefly = {
      url = "github:timhae/firefly";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      inherit (self) outputs;
      lib = nixpkgs.lib // home-manager.lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forEachSystem = f: lib.genAttrs systems (sys: f pkgsFor.${sys});
      pkgsFor = nixpkgs.legacyPackages;
    in
    {
      inherit lib;
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;
      templates = import ./templates;

      overlays = import ./overlays { inherit inputs outputs; };
      hydraJobs = import ./hydra.nix { inherit inputs outputs; };

      packages = forEachSystem (pkgs: import ./pkgs { inherit pkgs; });
      devShells = forEachSystem (pkgs: import ./shell.nix { inherit pkgs; });
      formatter = forEachSystem (pkgs: pkgs.nixpkgs-fmt);

      wallpapers = import ./home/gburd/wallpapers;

      nixosConfigurations = {
        # Personal laptop - Lenovo Carbon X1 Extreme Gen 5 - x86_64
        loki =  lib.nixosSystem {
          modules = [ ./hosts/loki ];
          specialArgs = { inherit inputs outputs; };
        };

        # Work laptop - MacBook Air macOS/nix - aarch64
        # ? =  lib.nixosSystem {
        #   modules = [ ./hosts/? ];
        #   specialArgs = { inherit inputs outputs; };
        # };

        # Main desktop - Intel NUC Skull Canyon - x86_64
        # ? = lib.nixosSystem {
        #   modules = [ ./hosts/? ];
        #   specialArgs = { inherit inputs outputs; };
        # };

        # Core server (?)
        # ? = lib.nixosSystem {
        #   modules = [ ./hosts/? ];
        #   specialArgs = { inherit inputs outputs; };
        # };

        # Build and game server (?)
        # ? = lib.nixosSystem {
        #   modules = [ ./hosts/? ];
        #   specialArgs = { inherit inputs outputs; };
        # };
      };

      homeConfigurations = {
        # Desktops
        "gburd@loki" = lib.homeManagerConfiguration {
          modules = [ ./home/gburd/loki.nix ];
          pkgs = pkgsFor.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
        };
        "gburd@generic" = lib.homeManagerConfiguration {
          modules = [ ./home/gburd/generic.nix ];
          pkgs = pkgsFor.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
        };
      };
    };
}
