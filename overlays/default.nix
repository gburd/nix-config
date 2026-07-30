# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: prev:
    (import ../pkgs { pkgs = final; })
    // rec {
      templateFile = name: template: data:
        prev.stdenv.mkDerivation {
          name = "${name}";

          nativeBuildInpts = [ prev.mustache-go ];

          # Pass Json as file to avoid escaping
          passAsFile = [ "jsonData" ];
          jsonData = builtins.toJSON data;

          # Disable phases which are not needed. In particular the unpackPhase will
          # fail, if no src attribute is set
          phases = [ "buildPhase" "installPhase" ];

          buildPhase = ''
            ${prev.mustache-go}/bin/mustache $jsonDataPath ${template} > file
          '';

          installPhase = ''
            cp file $out
            chmod +x $out
          '';
        };

      templateFileContent = n: t: d: builtins.readFile "${templateFile n t d}";
    };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  # Example usage
  modifications = _final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });

    # pipx 1.8.0's own test suite fails on nixos-26.05 (7 tests in
    # test_package_specifier.py, all a `packaging`-library string-
    # formatting difference -- e.g. asserting 'black@ https://...' where
    # the installed `packaging` version now normalizes to 'black @
    # https://...' with a space). This is nixpkgs' own package check
    # failing against a newer `packaging`, not anything in this repo --
    # confirmed via `nix log`, no matching upstream nixpkgs issue found
    # yet. pipx is a real dependency here (hermes-agent/litellm/maki/
    # pocket-tts all install via it), so skip just ITS test suite rather
    # than block every switch on an unrelated upstream test regression.
    #
    # MUST use overridePythonAttrs, not plain overrideAttrs -- confirmed
    # live (built both, compared drvPath): pkgs.pipx is produced via
    # buildPythonPackage + toPythonApplication
    # (pkgs/top-level/all-packages.nix: `with python3.pkgs;
    # toPythonApplication pipx`), and buildPythonPackage's extra
    # derivation-construction logic means a plain overrideAttrs call is a
    # silent no-op here (drvPath stayed byte-identical) --
    # overridePythonAttrs is the mechanism that actually threads through.
    pipx = prev.pipx.overridePythonAttrs (_oldAttrs: { doCheck = false; });

    customMaintainer = prev.lib.maintainers.overrideAttrs (oldAttrs: oldAttrs // {
      tcarrio = {
        email = "tom@carrio.dev";
        github = "tcarrio";
        githubId = 8659099;
        name = "Tom Carrio";
      };
    });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  };
  trunk-packages = final: _prev: {
    trunk = import inputs.nixpkgs-trunk {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  };
}
