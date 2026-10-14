# riscv64-linux compatibility overlay.
#
# Applied by home-manager/default.nix on EVERY host, but each override is a
# no-op unless the host platform is riscv64 -- so x86_64/aarch64 derivations
# are byte-identical with and without this file (checked by comparing drvPaths).
#
# Why it exists: adding lixr (SpacemiT K3, riscv64-linux, 2026-10-14) showed
# that 18 of the 211 packages in gburd's shared home.packages fail to EVALUATE
# on riscv64. The causes fall into families, and this file handles them by
# family at one central point instead of guarding 25 shared mixins one by one.
#
# FAMILY 1 -- GHC, reached only for MAN PAGES. nixpkgs ships no bootstrap GHC
# for riscv64 ("cannot bootstrap GHC on this platform"; 9.8.4-binary.nix lists
# only aarch64/x86_64 darwin+linux and i686-linux). eza and httpie are NOT
# Haskell -- they reach GHC only through pandoc, which their postInstall uses
# to render a markdown man page. Dropping pandoc from nativeBuildInputs alone
# makes the drv EVALUATE but the build would then FAIL, because postInstall
# still runs `pandoc`; so the pandoc invocation and its installManPage are
# removed too. Cost on riscv64: no man pages for these two. --help still works.
#
# Not handled here, and why: packages that ARE Haskell (ShellCheck, nixfmt,
# nil, nix-diff, nix-tree, dconf2nix, and actionlint/bash-language-server via
# ShellCheck) cannot be rescued by dropping a doc step -- the program itself
# needs GHC. Those are filtered out of the riscv64 package lists instead (see
# lib.riscvSafe in home-manager/default.nix).
_final: prev:
let
  isRiscv = prev.stdenv.hostPlatform.isRiscV64;

  # Remove pandoc from a derivation's build inputs and delete the postInstall
  # lines that call it. `marker` is a literal that appears only on the pandoc
  # line(s), so a mismatch fails loudly in the build rather than silently.
  withoutPandocMan = pkg: lines: pkg.overrideAttrs (old: {
    nativeBuildInputs = builtins.filter
      (d: !(builtins.elem (d.pname or "") [ "pandoc" "pandoc-cli" ]))
      (old.nativeBuildInputs or [ ]);
    postInstall = builtins.foldl'
      (acc: l: builtins.replaceStrings [ l ] [ "" ] acc)
      (old.postInstall or "")
      lines;
  });
in
prev.lib.optionalAttrs isRiscv {
  # The WHOLE man-page loop goes, not just the pandoc line: removing only
  # `pandoc ... >"man/$page"` would leave `sed ... |` dangling at the end of a
  # pipe, a shell syntax error. The loop body below is copied from nixpkgs'
  # eza postInstall; if upstream changes it, replaceStrings stops matching,
  # pandoc is invoked, and the riscv64 build fails loudly -- not silently.
  eza = withoutPandocMan prev.eza [
    ''
      for page in eza.1 eza_colors.5 eza_colors-explanation.5; do
        sed "s/\$version/v${prev.eza.version}/g" "man/$page.md" |
          pandoc --standalone -f markdown -t man >"man/$page"
      done
    ''
    "installManPage man/eza.1 man/eza_colors.5 man/eza_colors-explanation.5"
  ];

  httpie = withoutPandocMan prev.httpie [
    "pandoc --standalone -f markdown -t man docs/README.md -o docs/http.1"
    "installManPage docs/http.1"
  ];
}
