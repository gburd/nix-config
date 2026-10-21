# Benchmarking: measure correctly or say it's unstable

Rules for any performance measurement (CPU, memory, IO, a library, a service).
If a control below cannot be set, **report the result as unstable** rather than
reporting a number as a finding. Distilled from published practice (Andres
Freund, Tomas Vondra; Brendan Gregg; the LLVM and Mozilla guides) and the
measurement-bias literature (Mytkowicz 2009, Kalibera & Jones 2013, Chen &
Revels 2016). For the step-by-step runner, see the `benchmark` and
`tune-os-for-benchmark` skills; this is the rule set those skills enforce.

## Hard rules

1. **Never report a single run.** Run long enough to be real (minutes, not
   seconds), and repeat to check reproducibility.
2. **Never run all-A then all-B.** Frequency and thermal drift over a long
   sequence will masquerade as a difference. Interleave (ABBA), and randomize
   order where you can.
3. **Run an A/A test first** — the same build against itself. Any A/B
   difference at or below the A/A run-to-run spread is noise, not a result. If
   runs vary by ~200 units, a 1000-vs-1100 difference means nothing.
4. **A pinned result is a pinned result.** CPU pinning cuts noise but can hide
   real behaviour (Vondra). Label pinned results as pinned and say how.
5. **Low noise is necessary but not sufficient.** Measurement bias survives a
   quiet machine: link order and environment size alone have flipped
   O2-vs-O3 conclusions (Mytkowicz). A clean A/A floor does not license a
   causal claim.
6. **Don't change a host's settings without the owner's OK.** Boost/idle/
   governor changes are "do not do this in production" (Freund). Print the
   commands and ask first. On a shared or employer machine, treat every knob
   as off-limits until granted.
7. **If the environment can't be controlled, say so.** Use the verdicts below.

## Preflight (ask before running any that change the host)

| Control | Action | Why |
|---|---|---|
| Quiesce | Stop other work; let load average reach ~0 | background noise |
| Turbo/boost off | Intel `echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo`; AMD `echo 0 > /sys/devices/system/cpu/cpufreq/boost` | "slower but predictable" |
| Governor | `performance` | frequency scaling swings results |
| Idle states | `cpupower idle-set -D0` (re-enable `-E`), or boot `idle=poll` | post-idle latency is visibly higher; both cost turbo, pick one and record it |
| Pinning | `numactl --physcpubind <cpus> <task>` (pinning a parent pins children) | cores differ up to ~15% in boost; some get more interrupts |
| Client/server placement | record it | same-core vs cross-core changes throughput |
| THP | `enabled` and `defrag` = `never` | background defrag stalls |
| ASLR/SMT | disable ASLR, offline SMT siblings, `cset shield` | isolation (LLVM reports <0.1% variance) |
| Page/buffer cache | `echo 3 > /proc/sys/vm/drop_caches` for cold runs | note: does NOT clear an SSD's own DRAM cache |
| SSD | overprovision, `fstrim -v` between runs, use part of the drive, wait between write-heavy runs | write throughput degrades over time |
| Counters | confirm hardware counters work | under virtualization `perf` falls back to timer sampling, "very inaccurate" |
| Build | optimized/release build, not a debug/assert build | debug builds are unrepresentative |
| Real clock | measure actual freq via APERF/MPERF | turbo can skew comparisons >10%, verify it's really off |

**Record the environment** every run: CPU model + microcode, kernel, governor,
boost, idle states, THP, SMT, NUMA layout, VM-or-metal, storage model, free
disk, compiler, build flags, and the commit. A change in any item invalidates
comparison with earlier results.

## Run protocol

1. **Warm up to steady state**, then measure; discard the warmup. Find the
   steady point from a live progress trace, don't guess.
2. **Duration:** long enough that the measured window dwarfs startup transients.
3. **Order:** ABBA-interleave; wait between batches for storage and temperature
   to settle (seconds to minutes depending on the cause).
4. **Constant work** for counter comparisons, so absolute counts compare.
5. **Binary layout is a confounder.** A sub-~5% effect needs several builds with
   shuffled section layout (`mold --shuffle-sections <seed>`); summarize across
   builds.

## Statistics

- **Repeat at several levels** (builds, executions, iterations); spend
  repetitions where uncertainty is largest; report an effect-size confidence
  interval, not a bare ratio.
- **Summary statistic by context:** the **minimum** for microbenchmarks in a
  fixed binary (timing noise only adds delay — heavy-tailed, non-i.i.d.); the
  **median across layouts** for whole-system throughput.
- **Repetition has limits:** it cannot remove correlated environmental bias.
- **Continuous benchmarking:** use change-point detection (e.g. E-Divisive
  means) over static thresholds (which gave up to 99% false positives), and a
  constant "canary" workload to flag a bad run.

## Instability decision table

| Symptom | Likely cause | Test |
|---|---|---|
| Later runs faster/slower in fixed order | frequency/thermal drift | reverse order; check APERF/MPERF |
| Write tests degrade over time | SSD state | `fstrim`, rest, rerun |
| Same code, new build, 1–5% shift | binary layout | multi-build shuffle |
| Fast on one core, slow on another | core variation/interrupts | pin to different cores |
| Low-client latency changes after idle | C-states | `idle-set -D0` and compare |
| First runs after restart slow | page faults / cold cache | warm up |
| Random stalls | THP defrag | set `never` |
| `perf` too coarse | no hardware counters | check for virtualization |
| Result moves with no config change | host/hardware changed | diff the environment record |

**Verdicts:** `STABLE` (A/A within threshold); `NOISY — CONCLUSION LIMITED`
(list the uncontrolled items); `UNSTABLE — NO CLAIM` (A/A spread exceeds the
claimed effect).

## Platform reality

- **Cloud metal (e.g. EC2):** no BIOS access (firmware is abstracted), but the
  OS can control C-/P-states, governor, boost, pinning, and `fstrim`. SMT is
  OS-offline only; SNC/UPI/memory/prefetchers are fixed; firmware/hardware is
  not guaranteed stable across the life of a rented host; long waits cost money.
- **Owned hardware** adds: a frozen configuration held for years, control of the
  silicon (core-to-core variance), thermals, a chosen/dedicated SSD, and free
  long soak/rest periods. It is necessary only when the question needs a
  BIOS-level change or a configuration held fixed over time; most OS-level
  controls are equal on both.
- **Engineering-sample CPUs** are fine for same-box A/B, but their absolute
  numbers may not transfer to retail parts — don't compare them against cloud
  or production absolutes.

## Report template

Hypothesis; environment record; A/A noise floor; order and number of runs;
builds used; summary statistic and why; effect with a confidence interval;
verdict; the list of uncontrolled items.
