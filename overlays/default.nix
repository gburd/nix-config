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

  # BitNet 1-bit LLM inference (from bitnet-flake)
  # Wraps upstream to fix: huggingface_hub[cli] missing + 'huggingface-cli' renamed to 'hf'
  bitnet-packages = final: _prev:
    let
      wrapBitnet = name: pkg:
        if pkg == null then null
        else final.writeShellScriptBin name ''
          VENV_DIR="''${HOME}/.cache/bitnet/venv"
          REPO_DIR="''${HOME}/.cache/bitnet/BitNet"
          # Install huggingface_hub if missing
          if [ -d "$VENV_DIR" ] && ! [ -x "$VENV_DIR/bin/hf" ]; then
            "$VENV_DIR/bin/pip" install -q "huggingface_hub[cli]" 2>/dev/null || true
          fi
          # Patch deprecated 'huggingface-cli' -> 'hf' in setup_env.py
          if [ -f "$REPO_DIR/setup_env.py" ]; then
            ${final.gnused}/bin/sed -i 's/huggingface-cli/hf/g' "$REPO_DIR/setup_env.py" 2>/dev/null || true
          fi
          exec ${pkg}/bin/${name} "$@"
        '';
    in {
      bitnet = wrapBitnet "bitnet-bitnet-2B-4T" (inputs.bitnet-flake.packages.${final.stdenv.hostPlatform.system}.default or null);
      bitnet-3B = wrapBitnet "bitnet-bitnet-3B" (inputs.bitnet-flake.packages.${final.stdenv.hostPlatform.system}.bitnet-3B or null);
    };
}
