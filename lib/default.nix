{ self, inputs, outputs, stateVersion, ... }:
# Every helper defined in helpers.nix is exported automatically.
#
# This used to be an explicit `inherit (helpers) mkHome mkHost ...` list, which was
# an export BOUNDARY: defining a function in helpers.nix was not enough to make it
# visible as libx.<name>, and a helper missing from the list failed at the CALL SITE
# with "attribute '<name>' missing" -- which reads like a typo in the caller rather
# than a missing export. mkSolnixHost cost exactly that, one wasted evaluation.
#
# The list also bought nothing: audited at the time of this change, helpers.nix
# defined 8 helpers and the list named the same 8, so it was pure duplication whose
# only effect was to fail on the NEXT addition.
import ./helpers.nix { inherit self inputs outputs stateVersion; }
