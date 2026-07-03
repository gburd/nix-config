{ ... }:
# systemd-oomd tuning.
#
# Problem: systemd-oomd reclaims memory at CGROUP granularity — when a
# cgroup crosses its pressure/swap limits, oomd kills the WHOLE cgroup, not
# a single process. GNOME places every terminal window of one app (all
# Alacritty windows + their shells) into ONE app scope
# (app-gnome-Alacritty-<pid>.scope). So one runaway process (e.g. a build or
# DB that eats all RAM) makes oomd reap the entire scope = every terminal
# window dies at once.
#
# On these dev workstations that intentionally run memory-heavy builds and
# databases, that whole-cgroup reaping is worse than the kernel OOM killer,
# which selects a SINGLE worst-offender process (the scopes have
# memory.oom.group=0, so the kernel won't group-kill). Disable systemd-oomd
# so memory pressure falls through to the kernel OOM killer: only the
# offending process is terminated, other terminal windows survive.
#
# Trade-off: without oomd there's no early pressure-based intervention, so a
# true memory exhaustion is handled slightly later (at kernel OOM time)
# rather than pre-emptively. With ample RAM + swap that's the desired
# behavior here.
{
  systemd.oomd.enable = false;
}
