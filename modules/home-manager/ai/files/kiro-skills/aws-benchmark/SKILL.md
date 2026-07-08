---
name: aws-benchmark
description: >
  Run performance benchmarks on AWS EC2 (bare-metal or regular instances) with
  a reproducible launch → tune → measure → terminate workflow. Use for ANY AWS
  benchmarking — CPU/memory/IO/database/application, NUMA-related or not:
  choosing + launching an instance, one-time key-pair/security-group setup, OS
  kernel tuning (hugepages, governor, THP, NUMA balancing), EBS provisioning,
  A/B methodology, collecting results, and (critically) terminating the
  instance when done so it stops costing money. Triggers on: "benchmark on
  AWS/EC2", "bare-metal EC2", "launch an instance to test", "A/B benchmark",
  "clock sweep / NUMA benchmark", "pgbench/HammerDB on EC2". For the
  PostgreSQL-buffer-manager clock-sweep specifics, this pairs with the
  pg-numa-benchmark skill (which uses this one for the AWS substrate).
---

# AWS Benchmark

A reproducible EC2 benchmarking workflow. The steps below are
benchmark-agnostic (any workload); load your specific build/data/runner in the
"workload" step. **Always terminate the instance when finished.**

## Instance quick-reference (bare-metal, for hardware-faithful benchmarks)

| Instance        | vCPUs | NUMA nodes | RAM   | Region    | ~Cost/hr |
|-----------------|-------|------------|-------|-----------|----------|
| r8i.metal-96xl  | 384   | 6 (SNC3)   | 3 TB  | us-east-2 | $14.45   |
| m6i.metal       | 128   | 2          | 512GB | us-east-1 | $4.61    |
| c7i / m7i / r7i | var   | 1–2        | var   | any       | var      |

Use bare-metal (`.metal`) only when you need real NUMA topology / no
hypervisor jitter; otherwise a regular large instance is cheaper and fine.

## Workflow

1. **Account/CLI**: `aws sts get-caller-identity` to confirm the profile/account
   (see the aws-builder steering for auth). Pick a region.
2. **One-time**: create a key pair + a security group allowing SSH from your IP.
3. **Launch**: find the latest Amazon Linux 2023 AMI, launch the instance with
   a provisioned EBS data volume (e.g. gp3, 16K IOPS, 1 GB/s) sized to the
   dataset. Wait for SSH.
4. **OS bootstrap / tune** (the reusable, high-impact part):
   - hugepages pre-allocated for the workload's large allocations;
   - `transparent_hugepage=never` (THP interferes with explicit hugepages);
   - CPU governor = `performance` (disable frequency scaling);
   - disable NUMA balancing for deterministic placement
     (`kernel.numa_balancing=0`); pin with `numactl` where relevant;
   - mount the EBS data volume; verify topology with `numactl -H` / `lscpu`.
5. **Workload**: build/install what you're testing; load test data.
6. **Measure**: **A/B alternate** the two variants at each parameter point
   (not all-A then all-B) to cancel drift; ≥3 runs each; record raw CSV.
7. **Collect**: pull the CSVs, compute medians, note variance.
8. **TERMINATE the instance** (`aws ec2 terminate-instances`) — bare-metal is
   $4–14/hr; a forgotten instance is the single biggest cost mistake.

## Critical rules

- **Terminate when done.** Set a mental (or literal) alarm; check the console.
- **A/B alternation**, not batched — hardware/thermal/neighbor drift over a
  long run will otherwise bias whichever variant ran second.
- **Deterministic placement**: `numactl --cpunodebind=N` / `--membind=N` for
  NUMA-sensitive workloads; pin IRQs/threads where it matters.
- **Size the dataset vs. cache**: to exercise eviction/IO paths, the working
  set must exceed the relevant cache (RAM / buffer pool), or you only measure
  the cache.
- **gp3 EBS**: provision IOPS + throughput explicitly (defaults throttle).

## PostgreSQL clock-sweep / NUMA specifics

For the specific PG buffer-manager clock-sweep A/B (stock vs patched,
pgbench/HammerDB, `--with-libnuma`, shared_buffers sizing, expected +16-20% RO
deltas), use the **pg-numa-benchmark** skill — it layers the PG specifics on
top of this AWS substrate, with a full step-by-step reference guide.
