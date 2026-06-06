_:
{
  # Persistent scratch space for builds, tests, and benchmarks. World-writable
  # with the sticky bit (mode 1777, like /tmp) so any user can carve out their
  # own subdirectory. Lives on the real disk, not tmpfs — agents and tools
  # use it instead of /tmp for IO-faithful work (esp. DB/storage benchmarks
  # where tmpfs is RAM-backed and gives misleading numbers, and to avoid
  # filling tmpfs which OOMs / fails with ENOSPC under heavy load).
  #
  # systemd-tmpfiles re-applies these rules at boot and on
  # `systemd-tmpfiles --create`, so /scratch survives rebuilds and stays
  # at the right mode even if something chmod'd it.
  systemd.tmpfiles.rules = [
    "d /scratch 1777 root root - -"
  ];
}
