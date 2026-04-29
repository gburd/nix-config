# PG NUMA Benchmark

Run PostgreSQL clock sweep benchmarks on bare-metal EC2 instances. Use when benchmarking PostgreSQL buffer manager changes on NUMA hardware.

## Quick Reference

| Instance | vCPUs | NUMA Nodes | RAM | Cost/hr |
|----------|-------|------------|-----|---------|
| r8i.metal-96xl | 384 | 6 (SNC3) | 3TB | $14.45 |
| m6i.metal | 128 | 2 | 512GB | $4.61 |

Region: us-east-2 for r8i, us-east-1 for m6i.

## Workflow

1. Launch bare-metal instance with 2TB gp3 EBS (16K IOPS, 1GB/s throughput)
2. Bootstrap: build deps, hugepages (17408 for 32GB), disable NUMA balancing, performance governor
3. Build stock PG to `/postgres/pg_stock`, patched to `/postgres/pg_patch` (both with `--with-libnuma`)
4. Load pgbench scale 3000 (~45GB, exceeds 32GB shared_buffers to force eviction)
5. A/B alternate stock/patched at each client count (64/128/256/384/512), 3 runs, 5min RO / 10min RW
6. Collect CSV results, compute medians
7. TERMINATE the instance

## Critical Rules

- **`numactl --cpunodebind=0`** on every `pg_ctl start` — deterministic NUMA placement
- **`--with-libnuma`** in configure — required for patch to detect NUMA topology
- **shared_buffers = 32GB** — must be < dataset size to trigger clock sweep
- **huge_pages = on** — pre-allocate hugepages or PG falls back to 4KB pages
- **Separate data dirs** — `/pgdata/stock` and `/pgdata/patch`, not shared
- **A/B alternation** — stock then patch at each client count, not all stock then all patch

## Expected Results

- pgbench RO (select-only): **+16-20%** (sweep is the bottleneck)
- pgbench RW (TPC-B): **~0%** (WAL-bottlenecked)
- HammerDB TPC-C: **no regression**

## Full Procedure

The complete guide with all scripts, postgresql.conf, HammerDB setup, and troubleshooting is in `~/.kiro/skills/pg-numa-benchmark/references/GREG_BENCHMARK_GUIDE.md`. Read it when executing the benchmark.
