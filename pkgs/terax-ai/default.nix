# Terax AI - vanilla upstream v0.7.3 with our local Linux blank-screen render
# fix only. Bedrock connectivity is no longer carried as a fork-patch; agents
# (incl. Terax) connect to AWS Bedrock through the local LiteLLM proxy on
# 127.0.0.1:4000 (modules/home-manager/ai/litellm.nix). On first launch,
# configure Terax once via Settings -> AI -> openai-compatible:
#   Base URL: http://127.0.0.1:4000/v1
#   API Key:  (contents of ~/.config/litellm/keys/terax.key)
# Terax persists this in its own Tauri keystore so the manual step is
# one-shot.
#
# First-time hash bootstrap (pnpmDeps.hash):
#   nix build .#terax-ai 2>&1 | grep "got:"
# Update hash below, then rebuild.
{ lib
, fetchFromGitHub
, rustPlatform
, nodejs
, pnpm
, jq
, cargo-tauri
, pkg-config
, wrapGAppsHook4
, gobject-introspection
, webkitgtk_4_1
, gtk3
, openssl
, dbus
, glib
, glib-networking
, libsoup_3
, libappindicator-gtk3
, xdotool
,
}:
let
  pname = "terax-ai";
  version = "0.7.3";
  src = fetchFromGitHub {
    owner = "crynta";
    repo = "terax-ai";
    rev = "v${version}";
    hash = "sha256-yy48tMW5XadrDNaqSBApgGl1LgduevqIUXsDiv5ejMk=";
  };
  patches = [ ./linux-render-fixes.patch ];
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
    hash = "sha256-1W/WQN5pfDr/Tqx40iqVNvHTVKvxY3DBT38F3ycuaSc=";
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

  # Patch tauri.conf.json for Linux compatibility:
  # - Disable updater artifact signing (Nix manages updates)
  # - Force window visible on creation (Linux WebKitGTK doesn't reliably fire show events)
  # - Remove overlay title bar (causes detached WebView on Linux GTK/WebKitGTK)
  postPatch = ''
    ${jq}/bin/jq '
      .bundle.createUpdaterArtifacts = false |
      .app.windows[0].visible = true |
      del(.app.windows[0].titleBarStyle) |
      del(.app.windows[0].hiddenTitle)
    ' src-tauri/tauri.conf.json > tauri.conf.patched.json
    mv tauri.conf.patched.json src-tauri/tauri.conf.json
  '';

  # WebKitGTK render env. Use --set-default (not --set) so it can be overridden
  # at runtime for experimentation, e.g. `GDK_BACKEND=wayland terax-ai` or
  # `WEBKIT_DISABLE_COMPOSITING_MODE=0 terax-ai`. Defaults mirror upstream's
  # NixOS packaging (issue #462): GDK_BACKEND fallback list + compositing off.
  # (DMABUF renderer is left enabled; disabling it did not help the blank
  # window and modern WebKitGTK 2.52 handles it.)
  preFixup = ''
    gappsWrapperArgs+=(
      --set-default GDK_BACKEND 'x11,wayland'
      --set-default WEBKIT_DISABLE_COMPOSITING_MODE 1
    )
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
