{ lib, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../../desktop/vorta.nix
  ];
  dconf.settings = { };
}
