# nixos/solnix/community.nix -- the maintainer's solnix hosts join the solnix.io community cache
# (solnix modules/config/community; docs/community-features.md). He opted ALL his solnix hosts in
# (2026-10-28):
#   * census: daily, anonymous; the edge derives the region from the IP;
#   * seeding: what each host fetched or built;
#   * building: the solnix.io queue, in idle time;
#   * builder identity: the host's own ssh-ed25519 key, kept in nixos/solnix/secrets.yaml (sops), with
#     contact greg+<host>-solnix@burd.me.
# The queue bearer is NOT in the store: an operator places solnix secrets/build-queue-bearer.yaml's
# `build-queue-bearer` at /var/lib/solnix/build-queue-bearer (0600 root). Without it the builder runs dry.
{ config, pkgs, ... }:
{
  solnix.privacy.enable = false;
  # BitTorrent fetch + seed. The swarm-health probe keeps it inert (straight HTTP, measured +0.0 s per NAR) while
  # tracker.solnix.io lists only its ingress IP; it turns itself on when a public seed shows up.
  solnix.cache.seed.torrentPackage = pkgs.solnix.solnix-torrent;
  solnix.builder.enable = true;
  solnix.builder.contactEmail = "greg+${config.networking.hostName}-solnix@burd.me";
}
