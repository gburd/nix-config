{ lib
, fetchFromGitHub
, rustPlatform
, pkg-config
, wrapGAppsHook4
, dbus
, glib
, libsoup_3
, poppler
, shared-mime-info
, webkitgtk_6_0
, gtk4
, libadwaita
, openssl
, sqlite
, gpgme
, libgpg-error
, gsettings-desktop-schemas
}:

# Hylki — a GNOME-native email client (GTK4 + libadwaita + relm4), AGPL-3.0,
# hyprlab/hylki. Not in nixpkgs (checked 2026-10-09).
#
# Built from source rather than from the release artifacts: upstream ships an
# .fc44 RPM and two Flatpaks, neither of which is a sane Nix input. The source
# is a plain cargo build (no meson, despite the GNOME stack) with a build.rs
# that calls glib_build_tools::compile_resources three times, for the icon,
# sender-logo and notification-sound gresource bundles -- hence glib in
# nativeBuildInputs for glib-compile-resources.
#
# wrapGAppsHook4 is required, not optional: this is a GTK4/libadwaita app and
# needs GSETTINGS_SCHEMA_DIR, GDK_PIXBUF_MODULE_FILE and the GIO module path
# set at runtime or it aborts on startup with a schema error.
#
# NOTE no darwin build. Upstream publishes no macOS artifact and the stack is
# GTK4/libadwaita against the GNOME 50 runtime, so the aws Mac cannot run this
# -- see the comment where it is (not) imported in darwin/default.nix.
rustPlatform.buildRustPackage rec {
  pname = "hylki";
  version = "1.43.1";

  src = fetchFromGitHub {
    owner = "hyprlab";
    repo = "hylki";
    tag = "v${version}";
    hash = "sha256-E+jNQ651OPuvWqX8SBmd88IZmNi6m0FHHQGRYQO0swI=";
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook4
    glib # glib-compile-resources, called from build.rs
    # Two unit tests (guess_mime_tests::types_attachments_by_suffix and
    # tests::build_email_carries_attachments) resolve attachment MIME types
    # through the shared MIME database and get application/octet-stream
    # instead of application/pdf without it. Supplying the database is better
    # than skipping the tests: it is what the app uses at runtime too.
    shared-mime-info
  ];

  # The MIME lookup reads XDG_DATA_DIRS, which the builder does not set.
  preCheck = ''
    export XDG_DATA_DIRS="${shared-mime-info}/share"
  '';

  buildInputs = [
    dbus # libdbus-sys: desktop notifications / secret-service lookups
    glib
    gtk4
    libsoup_3 # soup3-sys: HTTP for OAuth + remote image fetch
    poppler # poppler-sys-rs: inline PDF attachment preview
    webkitgtk_6_0 # HTML message rendering
    libadwaita
    openssl
    sqlite
    gpgme # OpenPGP support (upstream issue #133)
    libgpg-error
    gsettings-desktop-schemas
  ];

  # The repo's install.sh places the .desktop/icons/schemas; cargo's install
  # step only handles the binary, so do the data files here.
  postInstall = ''
    if [ -d data ]; then
      for d in data/*.desktop; do
        [ -e "$d" ] && install -Dm444 "$d" "$out/share/applications/$(basename "$d")"
      done
      for g in data/*.gschema.xml; do
        [ -e "$g" ] && install -Dm444 "$g" "$out/share/glib-2.0/schemas/$(basename "$g")"
      done
    fi
  '';

  meta = {
    description = "GNOME-native email client built with Rust and libadwaita";
    homepage = "https://hyprlab.co/hylki/";
    license = lib.licenses.agpl3Only;
    mainProgram = "hylki";
    platforms = lib.platforms.linux;
  };
}
