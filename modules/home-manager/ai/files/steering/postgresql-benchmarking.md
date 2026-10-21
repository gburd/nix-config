# PostgreSQL benchmarking: committer practice

PostgreSQL-specific rules on top of the generic `benchmarking.md` (read that
first: A/A floor, ABBA order, environment record, verdicts). These capture how
Postgres committers (Andres Freund, Tomas Vondra) actually measure, and the
traps specific to Postgres and pgbench. For the NUMA/EC2 clock-sweep runner see
the `pg-numa-benchmark` skill; this is the methodology it must obey.

## pgbench correctness

1. **Scale factor >= client count.** Otherwise you measure contention on
   `pgbench_branches`, not the thing under test.
2. **pgbench can be the bottleneck.** Confirm the driver isn't the limit before
   trusting a throughput number.
3. **Database state matters.** Results depend on time since init, dead rows and
   autovacuum. Rebuild/reset the database the same way before every run.
4. **Read-only vs read-write durations differ.** A read-only run can be ~1
   minute; a read-write run should span 2–3 checkpoints each (hours across a
   full set).
5. **Warm up with `pgbench -P 1`.** Watch the live trace to find steady state
   (e.g. ~25k -> ~100k tps over ~200 s), discard the warmup, then measure.

## Measure the right thing

- **Isolate the code under test.** The SQL form changes how much of the runtime
  is your code — from "unusable" to ~50%. Prefer a dedicated C benchmark
  function (e.g. a `deform_bench`-style helper) for microbenchmarks, and
  estimate the Amdahl fraction first: a 10x speedup on 1.5% of the workload
  moves total time from 60 to 59.19.
- **Don't profile contention with CPU cycles.** A `LOCK pgbench_accounts`
  workload barely moves from 1 to 8 clients. Use wait events or off-CPU
  profiling for contention.

## Postgres-specific noise sources

- **Shared-memory page faults.** The first runs after server start pay
  page-fault noise (the kernel reserves but doesn't touch pages). Warm up until
  it settles; the upstream fix is `MAP_POPULATE` in `sysv_shmem.c` (a possible
  developer GUC).
- **Cold-cache runs:** `pg_buffercache_evict_relation` (PG 18+) for shared
  buffers, `echo 3 > /proc/sys/vm/drop_caches` for the page cache. Neither
  clears the SSD's internal DRAM cache.
- **Very short queries are treacherous.** On a 176-core EPYC, read-only pgbench
  fell ~500k -> ~350k tps at ~22 clients and recovered near 100 — pinning moved
  or removed it, pipelining 5 queries removed it, and the root cause is
  unresolved. Before trusting a client-count curve, retest with pipelining and
  different client counts; a dip can be scheduler/idle interaction, not your
  change.

## Build discipline for Postgres

- Benchmark an **optimized** build. Do **not** benchmark `--enable-cassert` or
  debug-only builds — they are much slower and unrepresentative.
- For a sub-5% effect, build stock and patched **several times** with shuffled
  section layout and summarize across builds (layout alone is ~1–5% noise).
- Record the exact `configure`/meson flags and commit in the environment record
  (generic steering) — a compiler or flag change alone shifts results.

## Profiling Postgres

- Decide CPU-bound vs contention-bound first (wait events / off-CPU), then
  profile.
- Confirm hardware counters work (virtualization hides them).
- Build with frame pointers (`-fno-omit-frame-pointer`) for `perf` stack walks.
- `perf stat -ddd` for memory latency, dTLB/iTLB and branch misses; read both
  `perf report --children` and `--no-children`.
- iTLB-bound code: map the binary on huge pages
  (`-Wl,-zcommon-page-size=0x200000 -Wl,-zmax-page-size=0x200000`, or a
  `tmpfs huge=always` copy) — compatible with THP `never` for data only via the
  tmpfs route.

## Unverified / gaps (do not assert these)

- The claim that some BIOS settings exist only on a physical "under your desk"
  host and not on cloud metal is **unverified** — it is not in Freund's slides
  or the podcasts. Don't state it as sourced.
- No committer source was found on DWARF-vs-LBR unwinding, skid/PEBS, or symbol
  handling — flag those as the agent's own judgement, not established practice.
