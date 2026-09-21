# fx — Vercel Labs' tiny native coding agent (https://fx.sh/).
#
# Zig, ~6MB, model-agnostic. Upstream ships prebuilt STATICALLY LINKED binaries
# per platform, so this is a plain fetch+install (no Zig toolchain, no
# autoPatchelf, no dynamic deps -- verified `file`: "statically linked").
#
# ⚠️ UPSTREAM IS EXPERIMENTAL. fx self-describes as "status: experimental (use
# at your own risk, we will be making frequent changes)" and is on v0.0.x. The
# custom-model-connection settings this config relies on (to route fx through
# the local LiteLLM proxy) are a documented *preview* feature. Expect churn;
# bump `version` + the hashes together.
{ lib
, stdenvNoCC
, fetchurl
}:
let
  version = "0.0.10";

  # nix-prefetch-url'd per platform; refresh all four on a version bump.
  sources = {
    x86_64-linux = {
      asset = "fx-linux-x86_64.tar.gz";
      hash = "sha256-Rb9NiOeG9UkDmhDOFAKDG5k35xaVam75BaDTy+a9l68=";
    };
    aarch64-linux = {
      asset = "fx-linux-aarch64.tar.gz";
      hash = "sha256-JxNPrbl+mOXIRwcPlsIR2hsr/Jur9Vc7qnU3KCNi+9g=";
    };
    aarch64-darwin = {
      asset = "fx-macos-aarch64.tar.gz";
      hash = "sha256-s/ASHkb4InaQ3vcrkg2dH8KZ8Lc91+uROCvYNnQhmHY=";
    };
    x86_64-darwin = {
      asset = "fx-macos-x86_64.tar.gz";
      hash = "sha256-DdAbrfZtG4oP5Tjp/V5Cs7Tcr9aqkyfum5YRo9Adbhg=";
    };
  };

  src' = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "fx: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "fx-agent"; # not `fx`: nixpkgs' `fx` is antonmedv's JSON viewer
  inherit version;

  src = fetchurl {
    url = "https://github.com/vercel-labs/fx/releases/download/v${version}/${src'.asset}";
    inherit (src') hash;
  };

  sourceRoot = ".";

  # Static binary: just install it. `fx` is the only executable in the tarball
  # (alongside LICENSE + THIRD_PARTY_NOTICES.md).
  installPhase = ''
    runHook preInstall
    install -Dm755 fx "$out/bin/fx"
    install -Dm644 LICENSE "$out/share/doc/fx/LICENSE"
    install -Dm644 THIRD_PARTY_NOTICES.md "$out/share/doc/fx/THIRD_PARTY_NOTICES.md"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    got="$("$out/bin/fx" --version)"
    if [ "$got" != "${version}" ]; then
      echo "fx --version reported '$got', expected '${version}'" >&2
      exit 1
    fi
    runHook postInstallCheck
  '';

  meta = {
    description = "Tiny, open, native coding agent (Vercel Labs)";
    homepage = "https://fx.sh/";
    changelog = "https://github.com/vercel-labs/fx/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "fx";
    platforms = lib.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
