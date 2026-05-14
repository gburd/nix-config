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
  # Wraps upstream to fix: LD_LIBRARY_PATH, huggingface-cli rename, GGUF conversion bugs
  bitnet-packages = final: _prev:
    let
      wrapBitnet = name: pkg: hfRepo:
        let modelName = builtins.baseNameOf hfRepo;
        in if pkg == null then null
        else final.writeShellScriptBin name ''
          VENV_DIR="''${HOME}/.cache/bitnet/venv"
          REPO_DIR="''${HOME}/.cache/bitnet/BitNet"
          MODEL_NAME="${modelName}"
          GGUF_PATH="$REPO_DIR/models/$MODEL_NAME/ggml-model-i2_s.gguf"
          # Fix pip-installed numpy/torch needing system libs (use nix-ld path)
          export LD_LIBRARY_PATH="''${NIX_LD_LIBRARY_PATH:-/run/current-system/sw/share/nix-ld/lib}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          # Install huggingface_hub[cli] if missing
          if [ -d "$VENV_DIR" ] && ! [ -x "$VENV_DIR/bin/hf" ]; then
            "$VENV_DIR/bin/pip" install -q "huggingface_hub[cli]" 2>/dev/null || true
          fi
          # Patch deprecated 'huggingface-cli' -> 'hf' in setup_env.py
          if [ -f "$REPO_DIR/setup_env.py" ]; then
            ${final.gnused}/bin/sed -i 's/huggingface-cli/hf/g' "$REPO_DIR/setup_env.py" 2>/dev/null || true
          fi
          # Download official pre-converted GGUF if conversion would fail
          # The HF-to-GGUF converter has bugs for BitNet-2B-4T (architecture name
          # case, tokenizer format, packed uint8 weights). Microsoft publishes the
          # correctly converted GGUF at HF_REPO-gguf.
          if [ -d "$REPO_DIR/models/$MODEL_NAME" ] && [ ! -f "$GGUF_PATH" ]; then
            echo "Downloading pre-converted GGUF from ${hfRepo}-gguf..."
            "$VENV_DIR/bin/hf" download "${hfRepo}-gguf" "ggml-model-i2_s.gguf" \
              --local-dir "$REPO_DIR/models/$MODEL_NAME" 2>/dev/null || true
          fi
          exec ${pkg}/bin/${name} "$@"
        '';
    in {
      bitnet = wrapBitnet "bitnet-bitnet-2B-4T" (inputs.bitnet-flake.packages.${final.stdenv.hostPlatform.system}.default or null) "microsoft/BitNet-b1.58-2B-4T";
      bitnet-3B = wrapBitnet "bitnet-bitnet-3B" (inputs.bitnet-flake.packages.${final.stdenv.hostPlatform.system}.bitnet-3B or null) "1bitLLM/bitnet_b1_58-3B";
    };
}
