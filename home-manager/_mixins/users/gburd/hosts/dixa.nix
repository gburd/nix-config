{ ... }:
# dixa -- aarch64 solnix (Nix on illumos) host running HEADLESS in EC2 (the
# permanent AWS account). Like dixi but arm64: build/dev animal reached over
# SSH, no COSMIC desktop (desktop arg null -> no GUI closure in
# systems/solaris.nix).
#
# Solnix's roadmap has aarch64 as Phase 3 (an out-of-tree illumos port to
# integrate), so dixa is a staged target -- it evaluates now (profile shape),
# builds once solnix-pkgs supports aarch64-solaris.
{
  imports = [ ./_solnix-common.nix ];
}
