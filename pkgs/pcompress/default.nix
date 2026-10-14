# pcompress -- parallel compressor/archiver with dedup, delta compression and
# encryption. LGPL-3.0+.
#
# THIS IS A TEMPORARY LOCAL COPY. The same derivation is in flight upstream as
# NixOS/nixpkgs#573443 ("pcompress: init at 4.0.1", CI green, unmerged as of
# 2026-10-13). pcompress is NOT yet in nixpkgs or nixos-unstable -- `nix eval
# nixpkgs#pcompress` still suggests ncompress/mscompress -- so the package
# cannot come from pkgs.unstable the way netwatch does.
#
# RETIRE THIS FILE once #573443 merges and reaches our nixpkgs-unstable input:
# drop pkgs/pcompress, remove the pkgs/default.nix entry, and change the
# reference in home-manager/_mixins/console/default.nix to
# `unstable.pcompress`. Same pattern and same reason as the netwatch note
# there.
#
# Kept byte-for-byte in step with the PR except for two deliberate deltas:
#   * src points at Codeberg rather than the GitHub mirror (see the comment
#     on src below) -- the tarballs are identical, this just matches
#     meta.homepage.
#   * meta.maintainers is dropped: lib.maintainers.gburd exists only in the
#     PR's maintainer-list.nix addition, not in our pinned nixpkgs, so
#     referencing it here would fail to evaluate.
{ lib
, stdenv
, fetchurl
, autoconf
, automake
, libtool
, perl
, pkg-config
, which
, yasm
, openssl
, zlib
, bzip2
, llvmPackages
, versionCheckHook
, nix-update-script
,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "pcompress";
  version = "4.0.1";

  # The release tarball bundles the pinned lz4, zstd, libbsc and libarchive
  # sources (git submodules); pcompress patches libarchive and builds them
  # in-tree. GitHub's auto-generated archives omit the submodules.
  src = fetchurl {
    # Codeberg is the canonical home (see meta.homepage); the GitHub mirror
    # serves a byte-identical tarball. Verified 2026-10-13: both are
    # 11678379 bytes and both hash to the SRI below, which also matches
    # upstream's published pcompress-4.0.1.tar.gz.sha256
    # (b6958bff88188db35e02afa7630bbd844640754d24da9487c9ccbf093a0054d9).
    url = "https://codeberg.org/gregburd/pcompress/releases/download/v${finalAttrs.version}/pcompress-${finalAttrs.version}.tar.gz";
    hash = "sha256-tpWL/4gYjbNeAq+nYwu9hEZAdU0k2pSHycy/CToAVNk=";
  };

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    perl
    pkg-config
    which
  ]
  ++ lib.optional stdenv.hostPlatform.isx86_64 yasm;

  buildInputs = [
    openssl
    zlib
    bzip2
  ]
  ++ lib.optional stdenv.cc.isClang llvmPackages.openmp;

  strictDeps = true;
  __structuredAttrs = true;

  # ./config is a hand-written script, not autoconf. --portable: no host
  # CPU probing (SIMD paths are still chosen at run time).
  configureScript = "./config";
  dontDisableStatic = true;
  configureFlags = [
    "--portable"
    "--disable-wavpack"
  ];
  checkTarget = "check";
  enableParallelBuilding = true;

  doCheck = true;
  doInstallCheck = true;

  preConfigure = ''
    patchShebangs config test
  '';

  # LLVM libomp's topology probe asserts in the build sandbox on aarch64;
  # pcompress does not rely on thread affinity.
  preCheck = ''
    export KMP_AFFINITY=disabled
  '';

  postInstall = ''
    install -Dm644 COPYING COPYING.LESSER -t $out/share/doc/pcompress
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "-V";

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Parallel compressor and archiver with deduplication, delta compression and encryption";
    longDescription = ''
      Pcompress splits its input into chunks and compresses them in parallel
      with one of many algorithms (zstd, LZMA, PPMd, libbsc, LZ4, zlib, bzip2,
      or adaptive per-chunk selection). It can deduplicate within a chunk or
      across the whole input, delta-encode similar blocks, apply content
      filters (JPEG, PNM, x86 code, text) in archive mode, and encrypt and
      authenticate every chunk with AES or XSalsa20.
    '';
    homepage = "https://codeberg.org/gregburd/pcompress";
    changelog = "https://codeberg.org/gregburd/pcompress/src/tag/v${finalAttrs.version}/Changelog";
    license = lib.licenses.lgpl3Plus;
    mainProgram = "pcompress";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    badPlatforms = [ lib.systems.inspect.patterns.is32bit ];
  };
})
