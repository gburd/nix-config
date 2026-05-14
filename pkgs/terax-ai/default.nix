# Terax AI — built from source with AWS Bedrock bearer-token support patch
# (GitHub issue #138 tracks adding this upstream; drop the patch once merged)
#
# First-time hash bootstrap (pnpmDeps.hash):
#   nix build .#terax-ai 2>&1 | grep "got:"
# Update hash below, then rebuild.
{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  nodejs,
  pnpm,
  jq,
  cargo-tauri,
  pkg-config,
  wrapGAppsHook4,
  gobject-introspection,
  webkitgtk_4_1,
  gtk3,
  openssl,
  dbus,
  glib,
  glib-networking,
  libsoup_3,
  libappindicator-gtk3,
  xdotool,
}:
let
  pname = "terax-ai";
  version = "0.6.4";
  src = fetchFromGitHub {
    owner = "crynta";
    repo = "terax-ai";
    rev = "v${version}";
    hash = "sha256-q6TJFUpMS1dPrZWAnbfpbfCaZZToUvw6RDemPsaORJU=";
  };
  patches = [ ./bedrock.patch ];
in
rustPlatform.buildRustPackage {
  inherit pname version src patches;

  # Rust source lives in src-tauri/
  # cargoRoot: tells fetchCargoVendor where Cargo.lock / Cargo.toml are
  # buildAndTestSubdir: tells cargo-tauri.hook where to run `cargo tauri build` from
  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";
  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  # pnpm deps — pnpm-lock.yaml is at project ROOT (not in src-tauri/)
  pnpmDeps = pnpm.fetchDeps {
    inherit pname version src patches;
    fetcherVersion = 3;
    hash = "sha256-W9xiKcqr+EKwr0nNNZmVLVm9YqLnyZviGa+fqRYYur4=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    jq
    nodejs
    pnpm.configHook
    pkg-config
    wrapGAppsHook4
    gobject-introspection
  ];

  buildInputs = [
    webkitgtk_4_1
    gtk3
    openssl
    dbus
    glib
    glib-networking
    libsoup_3
    libappindicator-gtk3
    xdotool
  ];

  # Disable auto-updater artifact signing (Nix manages updates; no signing key needed)
  postPatch = ''
    ${jq}/bin/jq '.bundle.createUpdaterArtifacts = false' \
      src-tauri/tauri.conf.json > tauri.conf.patched.json
    mv tauri.conf.patched.json src-tauri/tauri.conf.json
  '';

  # Fix blank/dark window on Wayland (WebKitGTK DMA-BUF renderer issue)
  preFixup = ''
    gappsWrapperArgs+=(--set WEBKIT_DISABLE_DMABUF_RENDERER 1)
  '';

  postInstall = ''
    # Rename binary to match pname (cargo tauri build installs as 'terax')
    mv "$out/bin/terax" "$out/bin/terax-ai" 2>/dev/null || true

    # Desktop entry
    install -Dm444 src-tauri/icons/128x128.png \
      "$out/share/icons/hicolor/128x128/apps/terax-ai.png" 2>/dev/null || true
    mkdir -p "$out/share/applications"
    cat > "$out/share/applications/terax-ai.desktop" << 'DESKTOP'
    [Desktop Entry]
    Name=Terax AI
    Exec=terax-ai
    Icon=terax-ai
    Type=Application
    Categories=Development;ArtificialIntelligence;
    Comment=AI coding assistant (AWS Bedrock bearer-token support)
    DESKTOP
  '';

  meta = with lib; {
    description = "AI coding assistant with AWS Bedrock bearer-token support";
    homepage = "https://github.com/crynta/terax-ai";
    license = licenses.mit;
    mainProgram = "terax-ai";
    platforms = [ "x86_64-linux" ];
  };
}
