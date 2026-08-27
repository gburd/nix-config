{ ... }:
# dixi -- x86_64 solnix (Nix on illumos) host running HEADLESS in EC2 (the
# permanent AWS account). No COSMIC desktop: this is a build/dev animal reached
# over SSH, so it gets the console/cli + AI agent tooling only (the `desktop`
# arg is null -> systems/solaris.nix adds no GUI closure).
#
# Solnix's own roadmap has x86_64 as the primary/Phase-1 target, so dixi is the
# first solnix host expected to actually build once solnix-pkgs is wired.
{
  imports = [ ./_solnix-common.nix ];
}
