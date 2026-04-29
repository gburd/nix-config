# Reproducing the Clock Sweep Benchmarks — Guide for Greg

**Author:** Jim Mlodgenski
**Date:** 2026-04-28
**For:** Greg Burd (and Kiro)

This document has everything needed to reproduce our benchmark results
from scratch on a fresh laptop with no AWS CLI, no Isengard account, and
no prior EC2 setup. It's written so that Kiro can execute each step.

---

## Table of Contents

1. AWS Account & CLI Setup
2. EC2 Key Pair & Security Group
3. Launching the Instance
4. OS Bootstrap (runs automatically via user-data)
5. Building PostgreSQL (Stock + Patched)
6. Loading Test Data
7. Running pgbench Benchmarks
8. Running HammerDB TPC-C Benchmarks
9. Collecting Results
10. Cleanup
11. Appendix: Instance Types & NUMA Topologies
12. Appendix: postgresql.conf Explained
13. Appendix: Troubleshooting

---

## 1. AWS Account & CLI Setup

You need an AWS account with permission to launch bare-metal EC2
instances. If you're at AWS, your Isengard account works — ask your
manager for access to a dev/test account if you don't have one.

### Install the AWS CLI

macOS:
```bash
brew install awscli
```

Linux:
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip
sudo ./aws/install
```

Windows (WSL):
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip
sudo ./aws/install
```

### Configure credentials

```bash
aws configure
# AWS Access Key ID: <your key>
# AWS Secret Access Key: <your secret>
# Default region name: us-east-2
# Default output format: json
```

If using Isengard/SSO:
```bash
aws configure sso
# Follow the prompts for your SSO start URL
# Then: export AWS_PROFILE=<your-profile-name>
```

Verify it works:
```bash
aws sts get-caller-identity
```

### Region choice

We use **us-east-2 (Ohio)** for r8i instances and **us-east-1 (Virginia)**
for m6i. The r8i.metal-96xl is not available in all regions. Check:
```bash
aws ec2 describe-instance-type-offerings \
    --location-type availability-zone \
    --filters Name=instance-type,Values=r8i.metal-96xl \
    --region us-east-2 \
    --query 'InstanceTypeOfferings[].Location'
```

---

## 2. EC2 Key Pair & Security Group

### Create a key pair (one-time)

```bash
aws ec2 create-key-pair \
    --key-name numa-bench \
    --key-type rsa \
    --query 'KeyMaterial' \
    --output text \
    --region us-east-2 > ~/.ssh/numa-bench.pem

chmod 600 ~/.ssh/numa-bench.pem
```

### Create a security group (one-time)

```bash
# Create the group
SG_ID=$(aws ec2 create-security-group \
    --group-name numa-bench-sg \
    --description "NUMA benchmark SSH access" \
    --region us-east-2 \
    --query 'GroupId' --output text)

echo "Security Group: $SG_ID"

# Allow SSH from your IP
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp --port 22 \
    --cidr "${MY_IP}/32" \
    --region us-east-2
```

Save the SG_ID — you'll need it for launching instances.

---

## 3. Launching the Instance

### Find the latest Amazon Linux 2023 AMI

```bash
AMI=$(aws ec2 describe-images \
    --owners amazon \
    --filters \
        "Name=name,Values=al2023-ami-2023*-x86_64" \
        "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text \
    --region us-east-2)

echo "AMI: $AMI"
```

### Launch r8i.metal-96xl

This is the primary benchmark instance: 2 sockets, 192 cores, 384 vCPUs,
6 NUMA nodes (SNC3), ~3TB RAM. Cost is ~$14.45/hr — a full benchmark
run takes 4-6 hours (~$70-90).

```bash
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI" \
    --instance-type r8i.metal-96xl \
    --key-name numa-bench \
    --security-group-ids "$SG_ID" \
    --block-device-mappings '[{
        "DeviceName": "/dev/xvdb",
        "Ebs": {
            "VolumeSize": 2000,
            "VolumeType": "gp3",
            "Iops": 16000,
            "Throughput": 1000,
            "DeleteOnTermination": true
        }
    }]' \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=numa-bench}]' \
    --region us-east-2 \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance: $INSTANCE_ID"
```

**Alternative: m6i.metal** — cheaper (~$4.60/hr), 2 sockets, 128 vCPUs,
512GB RAM, 2 NUMA nodes. Good for initial testing. Replace
`r8i.metal-96xl` with `m6i.metal` and use `--region us-east-1`.

### Wait for the instance and get its IP

```bash
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region us-east-2

PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region us-east-2 \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "IP: $PUBLIC_IP"
```

### SSH in

Bare metal instances take 5-10 minutes to boot (firmware init). Wait
until SSH responds:

```bash
# Retry until SSH is up
until ssh -i ~/.ssh/numa-bench.pem -o StrictHostKeyChecking=no \
    -o ConnectTimeout=5 ec2-user@"$PUBLIC_IP" "echo ready" 2>/dev/null; do
    echo "Waiting for SSH..."
    sleep 15
done
```

---

## 4. OS Bootstrap

SSH in and run these as root. This installs build dependencies, tunes
the kernel for benchmarking, and sets up the data volume.

```bash
ssh -i ~/.ssh/numa-bench.pem ec2-user@"$PUBLIC_IP"
sudo -i
```

### Install packages

```bash
dnf install -y \
    numactl numactl-devel numactl-libs \
    perf sysstat htop bc jq screen wget \
    gcc make bison flex git perl \
    readline-devel zlib-devel libxml2-devel openssl-devel \
    libicu-devel systemtap-sdt-devel lz4-devel libzstd-devel
```

### Kernel tuning

```bash
# Calculate hugepages for shared_buffers=32GB
# 32GB / 2MB per hugepage = 16384, plus some headroom
cat > /etc/sysctl.d/99-bench.conf << 'EOF'
vm.nr_hugepages = 17408
kernel.numa_balancing = 0
vm.swappiness = 1
vm.dirty_background_ratio = 3
vm.dirty_ratio = 10
kernel.shmmax = 68719476736
kernel.shmall = 16777216
EOF
sysctl --system

# Disable transparent huge pages (interferes with explicit hugepages)
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# Set CPU governor to performance (disable frequency scaling)
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$gov" ] && echo performance > "$gov"
done
```

**Why these settings:**
- `vm.nr_hugepages = 17408`: Pre-allocates 2MB hugepages for PostgreSQL's
  `huge_pages = on`. Without this, PG falls back to 4KB pages and TLB
  misses dominate on large shared_buffers.
- `kernel.numa_balancing = 0`: Disables the kernel's automatic page
  migration. We want deterministic NUMA placement for benchmarking.
- CPU governor `performance`: Prevents frequency scaling from adding
  noise to measurements.

### Mount the data volume

```bash
# Find the EBS data volume (the one that's not the root volume)
# On r8i.metal-96xl it's typically /dev/nvme1n1
lsblk
DATA_DEV="/dev/nvme1n1"  # adjust if different

mkfs.xfs -f "$DATA_DEV"
mkdir -p /pgdata
mount -o noatime,nodiratime,allocsize=16m "$DATA_DEV" /pgdata
```

### Create the postgres user

```bash
useradd -M -r -d /postgres -s /bin/bash postgres
mkdir -p /postgres/build /numa_bench
chown -R postgres:postgres /postgres /pgdata /numa_bench
echo 'postgres ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/postgres
```

### Verify NUMA topology

```bash
numactl --hardware
```

On r8i.metal-96xl you should see:
```
available: 6 nodes (0-5)
node 0 cpus: 0-31 192-223
node 0 size: 504627 MB
...
node distances:
node   0   1   2   3   4   5
  0:  10  15  17  21  28  26
  1:  15  10  15  23  26  23
  2:  17  15  10  26  23  21
  3:  21  28  26  10  15  17
  4:  23  26  23  15  10  15
  5:  26  23  21  17  15  10
```

Socket 0 = nodes 0,1,2. Socket 1 = nodes 3,4,5. Distances 21+ are
cross-socket. This is the SNC3 topology that makes the clock sweep
bottleneck so visible.

---

## 5. Building PostgreSQL (Stock + Patched)

All remaining steps run as the `postgres` user:

```bash
sudo -u postgres -i
```

### Clone PostgreSQL source

```bash
cd /postgres/build
git clone https://git.postgresql.org/git/postgresql.git src
cd src
git log --oneline -1  # record the commit hash for reproducibility
```

### Build stock (unpatched) version

```bash
./configure --prefix=/postgres/pg_stock \
    --with-openssl --with-libxml --with-icu \
    --with-lz4 --with-zstd --with-libnuma \
    --enable-debug CFLAGS="-O2 -g"
make -j "$(nproc)"
make install

# Also build contrib (we need pg_buffercache)
cd contrib && make -j "$(nproc)" && make install && cd ..
```

### Build patched version

Copy the patch file to the instance first. From your laptop:

```bash
scp -i ~/.ssh/numa-bench.pem \
    v2-0001-Reduce-clock-sweep-atomic-contention-by-claiming-.patch \
    v2-0002-Improve-clock-sweep-batch-sizing-with-CPU-aware-a.patch \
    ec2-user@"$PUBLIC_IP":/numa_bench/
```

Then on the instance as postgres:

```bash
cd /postgres/build/src

# Apply patches
git apply /numa_bench/v2-0001-Reduce-clock-sweep-atomic-contention-by-claiming-.patch
git apply /numa_bench/v2-0002-Improve-clock-sweep-batch-sizing-with-CPU-aware-a.patch

# Build patched
make clean
./configure --prefix=/postgres/pg_patch \
    --with-openssl --with-libxml --with-icu \
    --with-lz4 --with-zstd --with-libnuma \
    --enable-debug CFLAGS="-O2 -g"
make -j "$(nproc)"
make install
cd contrib && make -j "$(nproc)" && make install && cd ..

# Revert patches for clean state
git checkout -- .
```

**Important:** `--with-libnuma` is required. Without it, the patch's
NUMA detection falls back to batch_size=1 (no batching), and you'll
measure zero difference.

Verify libnuma is linked:
```bash
ldd /postgres/pg_patch/bin/postgres | grep numa
# Should show: libnuma.so.1 => /lib64/libnuma.so.1
```

---

## 6. Loading Test Data

### Initialize the database

```bash
/postgres/pg_stock/bin/initdb -D /pgdata/main --no-sync
```

### Configure PostgreSQL

```bash
cat > /pgdata/main/postgresql.conf << 'EOF'
# === Benchmark Configuration ===
shared_buffers = 32GB
huge_pages = on
max_connections = 600
work_mem = 64MB
maintenance_work_mem = 2GB
effective_cache_size = 384GB

# WAL
wal_level = replica
wal_buffers = 256MB
max_wal_size = 16GB
min_wal_size = 4GB
checkpoint_completion_target = 0.9
checkpoint_timeout = 5min

# Planner
random_page_cost = 1.1
effective_io_concurrency = 200

# Background Writer
bgwriter_lru_maxpages = 1000
bgwriter_lru_multiplier = 4.0

# Connections
listen_addresses = 'localhost'

# Logging
logging_collector = on
log_directory = 'log'
log_checkpoints = on
log_min_duration_statement = 60000
log_line_prefix = '%m [%p] '

# Stats
track_io_timing = on
EOF
```

**Why shared_buffers = 32GB?** The pgbench scale-3000 dataset is ~45GB.
With 32GB shared_buffers, the working set exceeds the buffer pool,
forcing continuous eviction via the clock sweep. This is where the
atomic contention bottleneck appears. If shared_buffers were 64GB+,
the dataset would fit in cache and the sweep would barely run — no
bottleneck, no measurable improvement.

### Start PostgreSQL and load pgbench data

**CRITICAL: Always start with `numactl --cpunodebind=0`.**

This pins the postmaster to NUMA node 0. Since Linux uses first-touch
memory policy, shared_buffers get allocated on node 0's memory. Without
this, the postmaster lands on a random node each launch and we saw
**29% variance** in stock TPS (31K to 40K) purely from placement luck.

```bash
numactl --cpunodebind=0 /postgres/pg_stock/bin/pg_ctl \
    -D /pgdata/main start -w -l /pgdata/main/logfile

/postgres/pg_stock/bin/createdb pgbench

# Scale 3000 = ~45GB. Takes ~10-15 minutes on bare metal.
/postgres/pg_stock/bin/pgbench -i -s 3000 pgbench

/postgres/pg_stock/bin/psql pgbench -c "VACUUM ANALYZE"

# Checkpoint to flush everything to disk
/postgres/pg_stock/bin/psql pgbench -c "CHECKPOINT"

/postgres/pg_stock/bin/pg_ctl -D /pgdata/main stop -w
```

### Verify the data size

```bash
du -sh /pgdata/main/base/
# Should be ~45-50GB
```

---

## 7. Running pgbench Benchmarks

The benchmark alternates stock/patched runs at each client count to
control for thermal drift and background noise. We run 3 iterations
and report medians.

**Important reproducibility note:** Use separate data directories for
stock and patched. Initialize and load data under the stock binary into
`/pgdata/stock`, then copy it: `cp -a /pgdata/stock /pgdata/patch`.
Run the stock binary against `/pgdata/stock` and the patched binary
against `/pgdata/patch`. Using a single shared data directory produced
inconsistent results in our testing.

### The benchmark script

Save this as `/numa_bench/run_pgbench_ab.sh`:

```bash
#!/bin/bash
set -euo pipefail

PGDATA=/pgdata/main
STOCK=/postgres/pg_stock
PATCH=/postgres/pg_patch
CLIENTS="64 128 256 384 512"
RUNS=3
DURATION_RO=300   # 5 minutes per run
DURATION_RW=600   # 10 minutes per run (2x checkpoint_timeout)
RESULTS=/numa_bench/results

mkdir -p "$RESULTS"

stop_pg() {
    "$1/bin/pg_ctl" -D "$PGDATA" stop -w -t 120 2>/dev/null || true
    sleep 5
    # Wait for port to be free
    for i in $(seq 1 30); do
        ss -tlnp | grep -q ':5432 ' || break
        sleep 1
    done
}

start_pg() {
    numactl --cpunodebind=0 "$1/bin/pg_ctl" \
        -D "$PGDATA" -l "$PGDATA/logfile" start -w -t 120
    sleep 3
}

drop_caches() {
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    sleep 1
}

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$RESULTS/progress.log"
}

# Header
echo "label,mode,clients,run,tps,latency_ms" > "$RESULTS/pgbench.csv"

# ---- Read-Only (select-only) ----
log "=== pgbench Read-Only (select-only, scale 3000) ==="

for clients in $CLIENTS; do
    for run in $(seq 1 $RUNS); do
        # Stock
        drop_caches
        start_pg "$STOCK"
        log "stock RO c=$clients r=$run starting..."
        tps=$("$STOCK/bin/pgbench" -c "$clients" -j "$clients" \
              -T "$DURATION_RO" -S pgbench 2>&1 \
              | grep "^tps = " | head -1 | awk '{print $3}')
        lat=$("$STOCK/bin/pgbench" -c "$clients" -j "$clients" \
              -T "$DURATION_RO" -S pgbench 2>&1 \
              | grep "latency average" | awk '{print $4}')
        echo "stock,ro,$clients,$run,$tps,$lat" >> "$RESULTS/pgbench.csv"
        log "  stock RO c=$clients r=$run: $tps TPS"
        stop_pg "$STOCK"

        # Patched
        drop_caches
        start_pg "$PATCH"
        log "patch RO c=$clients r=$run starting..."
        tps=$("$PATCH/bin/pgbench" -c "$clients" -j "$clients" \
              -T "$DURATION_RO" -S pgbench 2>&1 \
              | grep "^tps = " | head -1 | awk '{print $3}')
        lat=$("$PATCH/bin/pgbench" -c "$clients" -j "$clients" \
              -T "$DURATION_RO" -S pgbench 2>&1 \
              | grep "latency average" | awk '{print $4}')
        echo "patch,ro,$clients,$run,$tps,$lat" >> "$RESULTS/pgbench.csv"
        log "  patch RO c=$clients r=$run: $tps TPS"
        stop_pg "$PATCH"
    done
done

# ---- Read-Write (TPC-B) ----
log "=== pgbench Read-Write (TPC-B, scale 3000) ==="

for clients in $CLIENTS; do
    for run in $(seq 1 $RUNS); do
        # Stock
        drop_caches
        start_pg "$STOCK"
        log "stock RW c=$clients r=$run starting..."
        tps=$("$STOCK/bin/pgbench" -c "$clients" -j "$clients" \
              -T "$DURATION_RW" pgbench 2>&1 \
              | grep "^tps = " | head -1 | awk '{print $3}')
        echo "stock,rw,$clients,$run,$tps," >> "$RESULTS/pgbench.csv"
        log "  stock RW c=$clients r=$run: $tps TPS"
        stop_pg "$STOCK"

        # Patched
        drop_caches
        start_pg "$PATCH"
        log "patch RW c=$clients r=$run starting..."
        tps=$("$PATCH/bin/pgbench" -c "$clients" -j "$clients" \
              -T "$DURATION_RW" pgbench 2>&1 \
              | grep "^tps = " | head -1 | awk '{print $3}')
        echo "patch,rw,$clients,$run,$tps," >> "$RESULTS/pgbench.csv"
        log "  patch RW c=$clients r=$run: $tps TPS"
        stop_pg "$PATCH"
    done
done

log "=== COMPLETE ==="
log "Results in $RESULTS/pgbench.csv"
cat "$RESULTS/pgbench.csv"
```

**Note on the script above:** The pgbench calls run twice (once for TPS,
once for latency). A cleaner version would capture the full output to a
file and parse both values from it. Feel free to improve this — the key
thing is the A/B alternation pattern and the `numactl --cpunodebind=0`
on every start.

### Run it

```bash
chmod +x /numa_bench/run_pgbench_ab.sh

# Run in screen so it survives SSH disconnects
screen -S bench
bash /numa_bench/run_pgbench_ab.sh

# Detach: Ctrl-A, D
# Reattach: screen -r bench
```

### Expected runtime

- 5 client counts × 3 runs × 2 labels × 5 min = ~2.5 hours (RO)
- 5 client counts × 3 runs × 2 labels × 10 min = ~5 hours (RW)
- Total: ~7.5 hours

To do a quick sanity check first, use `CLIENTS="128 256"` and `RUNS=1`.

### Expected results on r8i.metal-96xl

```
pgbench RO (select-only):
  Clients   Stock     Patched   Delta
  64        ~31,500   ~36,500   +16%
  128       ~31,700   ~37,900   +20%
  256       ~31,500   ~37,600   +19%
  384       ~31,400   ~37,500   +19%
  512       ~31,300   ~37,000   +18%

pgbench RW (TPC-B):
  Clients   Stock     Patched   Delta
  64        ~7,700    ~7,700    0%
  128       ~10,400   ~10,500   +1%
  256       ~12,400   ~12,500   +1%
  384       ~15,300   ~15,200   -1%
  512       ~17,900   ~18,000   0%
```

The key pattern: **RO shows +16-20%, RW is within noise.** This is
because RO workloads call StrategyGetBuffer() much more frequently
(every buffer access can trigger eviction when the working set exceeds
shared_buffers), while RW workloads are bottlenecked on WAL and
checkpoint I/O.

---

## 8. Running HammerDB TPC-C Benchmarks

HammerDB TPC-C is a more realistic mixed read-write workload. This is
the benchmark Andres will care about most — pgbench select-only is a
micro-benchmark; TPC-C is closer to real OLTP.

### Install HammerDB

```bash
cd /opt
sudo wget -q https://github.com/TPC-Council/HammerDB/releases/download/v5.0/hammerdb-5.0-prod-lin-rhel8.tar.gz
sudo tar xzf hammerdb-5.0-prod-lin-rhel8.tar.gz
sudo rm -f hammerdb-5.0-prod-lin-rhel8.tar.gz
sudo chown -R postgres:postgres /opt/HammerDB-5.0

# Verify it runs
cd /opt/HammerDB-5.0
./hammerdbcli << 'EOF'
puts "HammerDB OK"
exit
EOF
```

Use the `rhel8` tarball for Amazon Linux 2023. For Ubuntu, use the
`ubu24` variant.

### Build the TPC-C schema

This creates a 1000-warehouse database (~100GB). Takes 15-30 minutes.

```bash
# Start PG (stock is fine for schema build)
numactl --cpunodebind=0 /postgres/pg_stock/bin/pg_ctl \
    -D /pgdata/main -l /pgdata/main/logfile start -w

# Create the build script
cat > /numa_bench/hdb_build.tcl << 'EOF'
dbset db pg
dbset bm TPC-C
diset connection pg_host localhost
diset connection pg_port 5432
diset connection pg_superuser postgres
diset connection pg_superuserpass postgres
diset connection pg_defaultdbase postgres
diset tpcc pg_count_ware 1000
diset tpcc pg_num_vu 16
diset tpcc pg_storedprocs false
diset tpcc pg_partition false
buildschema
EOF

cd /opt/HammerDB-5.0
echo "yes" | ./hammerdbcli auto /numa_bench/hdb_build.tcl

# VACUUM the TPC-C database
/postgres/pg_stock/bin/psql -d tpcc -c "VACUUM ANALYZE"
/postgres/pg_stock/bin/psql -d tpcc -c "CHECKPOINT"

/postgres/pg_stock/bin/pg_ctl -D /pgdata/main stop -w
```

**Notes:**
- `pg_superuserpass` cannot be empty — HammerDB's Tcl internals break
  on empty strings. Set any value; with `trust` auth it's ignored.
- `pg_storedprocs false` and `pg_partition false` must be set explicitly.
- The database is named `tpcc` by default.

### The HammerDB benchmark script

Save as `/numa_bench/run_hammerdb_ab.sh`:

```bash
#!/bin/bash
set -euo pipefail

PGDATA=/pgdata/main
STOCK=/postgres/pg_stock
PATCH=/postgres/pg_patch
VUS="128 256 384 512"
RUNS=3
DURATION=10     # minutes of steady-state measurement
RAMPUP=2        # minutes of ramp-up before measurement
RESULTS=/numa_bench/results
HAMMERDB=/opt/HammerDB-5.0

mkdir -p "$RESULTS"

stop_pg() {
    "$1/bin/pg_ctl" -D "$PGDATA" stop -w -t 120 2>/dev/null || true
    sleep 5
    for i in $(seq 1 30); do
        ss -tlnp | grep -q ':5432 ' || break
        sleep 1
    done
}

start_pg() {
    numactl --cpunodebind=0 "$1/bin/pg_ctl" \
        -D "$PGDATA" -l "$PGDATA/logfile" start -w -t 120
    sleep 5
}

drop_caches() {
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    sleep 1
}

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$RESULTS/progress.log"
}

run_hammerdb() {
    local vus=$1
    local wait_sec=$(( (DURATION + RAMPUP) * 60 + 300 ))

    cat > /numa_bench/hdb_run.tcl << RUNEOF
dbset db pg
dbset bm TPC-C
diset connection pg_host localhost
diset connection pg_port 5432
diset connection pg_superuser postgres
diset connection pg_superuserpass postgres
diset connection pg_defaultdbase postgres
diset tpcc pg_driver timed
diset tpcc pg_rampup $RAMPUP
diset tpcc pg_duration $DURATION
diset tpcc pg_count_ware 1000
diset tpcc pg_storedprocs false
vuset vu $vus
vuset logtotemp 1
vuset unique 1
loadscript
vucreate
vurun
runtimer $wait_sec
vudestroy
RUNEOF

    cd "$HAMMERDB"
    ./hammerdbcli auto /numa_bench/hdb_run.tcl 2>&1
}

echo "label,vus,run,nopm,tpm" > "$RESULTS/hammerdb.csv"

log "=== HammerDB TPC-C (1000 warehouses) ==="

for vus in $VUS; do
    for run in $(seq 1 $RUNS); do
        # Stock
        drop_caches
        start_pg "$STOCK"
        log "stock vu=$vus r=$run starting..."
        output=$(run_hammerdb "$vus")
        nopm=$(echo "$output" | grep "System achieved" | grep -oP '\d+ NOPM' | awk '{print $1}')
        tpm=$(echo "$output" | grep "System achieved" | grep -oP '\d+ .*TPM' | awk '{print $1}')
        echo "stock,$vus,$run,${nopm:-FAILED},${tpm:-FAILED}" >> "$RESULTS/hammerdb.csv"
        log "  stock vu=$vus r=$run: ${nopm:-FAILED} NOPM"
        stop_pg "$STOCK"

        # Patched
        drop_caches
        start_pg "$PATCH"
        log "patch vu=$vus r=$run starting..."
        output=$(run_hammerdb "$vus")
        nopm=$(echo "$output" | grep "System achieved" | grep -oP '\d+ NOPM' | awk '{print $1}')
        tpm=$(echo "$output" | grep "System achieved" | grep -oP '\d+ .*TPM' | awk '{print $1}')
        echo "patch,$vus,$run,${nopm:-FAILED},${tpm:-FAILED}" >> "$RESULTS/hammerdb.csv"
        log "  patch vu=$vus r=$run: ${nopm:-FAILED} NOPM"
        stop_pg "$PATCH"
    done
done

log "=== COMPLETE ==="
cat "$RESULTS/hammerdb.csv"
```

### Run it

```bash
chmod +x /numa_bench/run_hammerdb_ab.sh
screen -S hammerdb
bash /numa_bench/run_hammerdb_ab.sh
```

### Expected runtime

4 VU counts × 3 runs × 2 labels × 12 min = ~4.8 hours

### Expected results on m6i.metal

```
HammerDB TPC-C (1000 warehouses):
  VUs   Stock     Patched   Delta
  128   358,518   349,787   -2%
  256   332,098   330,272   -1%
  384   365,782   377,519   +3%
  512   370,663   386,526   +4%
```

The key result: **no regression.** TPC-C is write-heavy and the sweep
is not the primary bottleneck, so we don't expect a big improvement.
What matters is that we don't make things worse.

---

## 9. Collecting Results

### Download results to your laptop

```bash
scp -i ~/.ssh/numa-bench.pem -r \
    ec2-user@"$PUBLIC_IP":/numa_bench/results/ \
    ./benchmark_results/
```

### Also grab system info for the write-up

```bash
ssh -i ~/.ssh/numa-bench.pem ec2-user@"$PUBLIC_IP" \
    'numactl --hardware; echo "---"; lscpu; echo "---"; uname -a' \
    > ./benchmark_results/system_info.txt
```

### Computing medians

For each (label, mode, clients) group, take the median of 3 runs:

```bash
# Quick median calculation from the CSV
awk -F, 'NR>1 {key=$1","$2","$3; vals[key] = vals[key] " " $5}
END {
    for (k in vals) {
        n = split(vals[k], a, " ");
        asort(a);
        median = a[int((n+1)/2)];
        print k "," median
    }
}' benchmark_results/pgbench.csv | sort
```

---

## 10. Cleanup

**Don't forget to terminate the instance!** r8i.metal-96xl is ~$14.45/hr.

```bash
aws ec2 terminate-instances \
    --instance-ids "$INSTANCE_ID" \
    --region us-east-2

# Verify it's shutting down
aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region us-east-2 \
    --query 'Reservations[0].Instances[0].State.Name'
```

The EBS volume has `DeleteOnTermination: true` so it's cleaned up
automatically.

### Cost estimate

| Instance | Hourly | pgbench only (~3h) | Full suite (~8h) |
|----------|--------|-------------------|-----------------|
| r8i.metal-96xl | $14.45 | ~$43 | ~$116 |
| m6i.metal | $4.61 | ~$14 | ~$37 |

m6i.metal is a good starting point — it's 2-socket with clear NUMA
effects and 1/3 the cost.

---

## 11. Appendix: Instance Types & NUMA Topologies

| Instance | vCPUs | Sockets | NUMA Nodes | RAM | Cost/hr | Notes |
|----------|-------|---------|------------|-----|---------|-------|
| r8i.metal-96xl | 384 | 2 | 6 (SNC3) | 3TB | $14.45 | Primary. Granite Rapids. |
| m6i.metal | 128 | 2 | 2 | 512GB | $4.61 | Good & cheap. Ice Lake. |
| c8i.metal-48xl | 192 | 1 | 1 | 192GB | $8.57 | Single-socket control. |

**r8i.metal-96xl** is the most interesting because SNC3 creates 6 NUMA
nodes with 7 distinct distance tiers (10-28). The cross-socket atomic
penalty is extreme here.

**m6i.metal** is the best value — 2 sockets, clear NUMA effects, and
we have the most historical data on it.

**c8i.metal-48xl** is the single-socket control. With the v1 patch
(NUMA-only gating), batch_size=1 and there's no change. With v2
(CPU-aware tiering), batch_size=32 and you should see some improvement
on RO workloads.

### NUMA distance reference

m6i.metal (2 nodes):
```
node   0   1
  0:  10  21
  1:  21  10
```

r8i.metal-96xl (6 nodes, SNC3):
```
node   0   1   2   3   4   5
  0:  10  15  17  21  28  26
  1:  15  10  15  23  26  23
  2:  17  15  10  26  23  21
  3:  21  28  26  10  15  17
  4:  23  26  23  15  10  15
  5:  26  23  21  17  15  10
```

Socket 0 = nodes 0,1,2. Socket 1 = nodes 3,4,5.

---

## 12. Appendix: postgresql.conf Explained

| Setting | Value | Why |
|---------|-------|-----|
| `shared_buffers` | 32GB | Must be smaller than dataset (~45GB) to force eviction |
| `huge_pages` | on | Eliminates TLB misses on large shared_buffers |
| `max_connections` | 600 | Headroom for 512-client pgbench runs |
| `checkpoint_timeout` | 5min | Default. RW runs use 10min duration (2x) to smooth checkpoint effects |
| `max_wal_size` | 16GB | Prevents checkpoint storms during RW benchmarks |
| `bgwriter_lru_maxpages` | 1000 | Aggressive bgwriter to keep freelist populated |
| `bgwriter_lru_multiplier` | 4.0 | Aggressive bgwriter lookahead |
| `effective_cache_size` | 384GB | Tells planner about OS cache (doesn't affect benchmark) |
| `random_page_cost` | 1.1 | Reflects SSD storage (EBS gp3) |

---

## 13. Appendix: Troubleshooting

### "could not map anonymous shared memory: Cannot allocate memory"

Hugepages not allocated. Check:
```bash
grep -i huge /proc/meminfo
# HugePages_Total should be >= 17408 for 32GB shared_buffers
```

Fix: `sudo sysctl -w vm.nr_hugepages=17408`

### Stock TPS is ~40K instead of ~31K

The clock sweep bottleneck isn't manifesting. This can happen for
several reasons:

1. **Missing numactl pinning.** You forgot `numactl --cpunodebind=0`
   when starting PostgreSQL. The postmaster landed on a favorable node
   where most backends happen to be local. Stop, restart with numactl.

2. **Shared data directory.** If stock and patched runs use the same
   data directory (`/pgdata/main`), the buffer pool state from the
   previous run can affect the next. **Use separate data directories:**
   init and load on `/pgdata/stock`, then `cp -a /pgdata/stock /pgdata/patch`.
   Stock binary uses `/pgdata/stock`, patched binary uses `/pgdata/patch`.

3. **Too many variants per run.** When testing multiple configurations
   (e.g., batch sizes 4/8/16/32/64) in a single loop, later variants
   benefit from OS page cache warmth that `drop_caches` doesn't fully
   clear (filesystem metadata, readahead buffers). Test stock vs one
   patched variant first to confirm the bottleneck is present, then
   add more variants.

4. **Different git commit.** The PG source tree evolves daily. A commit
   that changes buffer access patterns or lock contention can shift the
   bottleneck. Pin to a specific commit with `git checkout <hash>` for
   reproducibility across runs.

We saw stock vary from 31K to 40K across different r8i launches. The
runs that reliably showed 31K (and thus the +19% improvement) all used:
- `numactl --cpunodebind=0` on pg_ctl
- Separate data directories for stock and patched
- A/B alternating (stock then patch, not all stock then all patch)
- Same git commit across all builds

### Stock and patched TPS are identical

1. Check that libnuma is linked: `ldd /postgres/pg_patch/bin/postgres | grep numa`
2. Check NUMA nodes: `numactl --hardware` — need 2+ nodes
3. Check that the patch is actually applied: look for `ClockSweepBatchSize`
   in the patched binary: `strings /postgres/pg_patch/bin/postgres | grep -i batch`

### pgbench errors: "connection to server failed"

max_connections is too low for the client count. Set it to at least
`clients + 10`.

### HammerDB "FAILED" in results

Check the raw output file. Common issues:
- Database `tpcc` doesn't exist (schema build failed)
- Port conflict (previous PG instance still running)
- `pg_superuserpass` set to empty string (breaks Tcl arg parsing)

### Instance won't launch: "InsufficientInstanceCapacity"

Bare metal instances have limited capacity. Try:
1. A different availability zone in the same region
2. A different region (us-east-1 for m6i, us-west-2 as fallback)
3. Wait and retry — capacity fluctuates

### Screen session lost

If your SSH disconnects, reconnect and reattach:
```bash
ssh -i ~/.ssh/numa-bench.pem ec2-user@"$PUBLIC_IP"
sudo -u postgres screen -r bench
```

If the screen session died, check progress:
```bash
cat /numa_bench/results/progress.log
cat /numa_bench/results/pgbench.csv
```
