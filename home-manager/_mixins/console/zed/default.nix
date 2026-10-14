{ lib, pkgs, ... }:
let
  # Zed editor -- only where it actually EVALUATES. zed-editor's own
  # meta.platforms includes riscv64-linux, so `lib.meta.availableOn` returns
  # TRUE there (checked) -- but its dependency livekit-libwebrtc throws
  # "unsupported arch riscv64" during evaluation. A metadata check cannot see
  # a dependency's eval failure, so test the derivation itself: tryEval
  # catches the throw and lets this shared mixin stay correct on every host
  # without naming any of them. Found adding lixr (riscv64), 2026-10-14.
  zedEvaluates = (builtins.tryEval pkgs.zed-editor.outPath).success;
in
{
  home.packages = lib.optional zedEvaluates pkgs.zed-editor;

  # Zed configuration -- plain files, harmless where the editor is absent.
  xdg.configFile."zed/settings.json".source = ./settings.json;
  xdg.configFile."zed/keymap.json".source = ./keymap.json;
}
