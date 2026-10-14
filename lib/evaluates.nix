# Keep only the packages that EVALUATE on the current platform.
#
# Usage, inside any home-manager module:
#   home.packages = import ../../lib/evaluates.nix [ a b c ];
#
# Why not lib.meta.availableOn: it reads a package's OWN meta.platforms and
# cannot see a dependency's failure. zed-editor, vorta and telegram-desktop
# all list riscv64-linux yet fail on it (livekit-libwebrtc "unsupported arch",
# qtwebengine "Refusing to evaluate"). builtins.tryEval on the outPath forces
# exactly the evaluation home.packages would, and catches the throw.
#
# On a platform where everything evaluates (every host before lixr), this
# returns the list unchanged, so their derivations do not move. It must NOT
# be used to paper over a broken package on such a host: the point is to drop
# things that cannot exist on the platform, not to hide regressions.
builtins.filter
  (p: (builtins.tryEval (builtins.seq (p.outPath or "") true)).success)
