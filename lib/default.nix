{ self, inputs, outputs, stateVersion, ... }:
let
  helpers = import ./helpers.nix { inherit self inputs outputs stateVersion; };
in
{
  inherit (helpers)
    mkHome
    mkHost
    mkWslHost
    mkDarwin
    mkRawImage
    mkSdImage
    forAllSystems;
}
