{ self, inputs, outputs, stateVersion, ... }:
let
  helpers = import ./helpers.nix { inherit self inputs outputs stateVersion; };
in
{
  # NOTE: this inherit list is the export boundary -- helpers.nix defining a
  # function is NOT enough to make it visible as libx.<name>. A new helper that
  # is not listed here fails at the CALL SITE with "attribute '<name>' missing",
  # which reads like a typo in the caller rather than a missing export.
  inherit (helpers)
    mkHome
    mkHost
    mkSolnixHost
    mkWslHost
    mkDarwin
    mkRawImage
    mkSdImage
    forAllSystems;
}
