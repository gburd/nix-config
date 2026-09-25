# AWS Burner Accounts

These are short-lived accounts for experiments, benchmarks, and throwaway
infrastructure. Using them is expected and encouraged. The rules below exist
because the accounts are shared, ephemeral, and metered, not because
experimentation needs discouraging.

## The one-week clock

Every burner account is deleted after one week, and deletion takes all its
resources with it. Nothing in a burner account is durable. Note that this is a
backstop for the account, not a substitute for cleaning up after yourself.

Two consequences worth internalising. First, anything you want to keep, whether
that is a benchmark result, a build artifact, a configuration you tuned, or a
log, must be copied somewhere permanent before the week is out. Second, the
sweep is not a license to leave resources running: a GPU instance left idle for
six days still costs real money and still consumes capacity another person
needed.

## Clean up when you finish, not when the clock does

Tear down what you created as soon as the work is done. The habit that actually
works is to write the teardown command at the same moment you write the
creation command, and to keep them together in whatever script or note you are
working from.

When you cannot tear something down immediately, tag it so the next person can
tell a live experiment from an abandoned one. Tag every resource you create
with an owner, a purpose, and an expiry, for example:

```
--tag-specifications 'ResourceType=instance,Tags=[
  {Key=Owner,Value=gburd},
  {Key=Purpose,Value=pg-clocksweep-bench},
  {Key=Expires,Value=2026-10-02}]'
```

Before you walk away for the day, ask what is still running and whether it
needs to be:

```
aws ec2 describe-instances \
  --filters 'Name=instance-state-name,Values=running' \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime,Tags[?Key==`Purpose`].Value|[0]]' \
  --output table
```

## Frugal, but not cheap where it matters

Be frugal with resources you are not using, and generous with the ones the job
actually needs. These are not in tension. A benchmark run on an undersized
instance, with too little memory or a throttled volume, produces a number that
is wrong, and a wrong number costs far more than the larger instance would
have: it costs the run, the analysis built on it, and often a second run to
discover the first was invalid.

So size for the job and be honest about what the job requires. If the work
needs a metal instance for stable NUMA behaviour, or provisioned IOPS so the
storage is not the bottleneck, use them. Then stop them the moment the
measurement is captured.

The waste worth hunting is idle waste: instances running overnight with nothing
on them, volumes detached from any instance, elastic IPs allocated to nothing,
snapshots of machines that no longer exist, NAT gateways left behind by a VPC
experiment. Those cost money continuously and buy nothing.

## AMI choice: not Amazon Linux

Use the latest **Fedora**, **Debian**, or **FreeBSD** AMI rather than Amazon
Linux.

The reason is fidelity. Amazon Linux carries a heavily patched kernel, its own
backported userland, and package versions that match nothing you run elsewhere,
so results obtained there do not transfer cleanly to other hosts and
reproducing a finding later is harder than it should be. Fedora tracks current
upstream closely, which is what you want when testing against a recent kernel
or toolchain. Debian gives a stable, widely understood baseline. FreeBSD is the
right choice when the work is actually about FreeBSD, and a useful second data
point when a result smells Linux-specific.

Resolve the AMI at launch time rather than pasting an ID from an old note, as
IDs are region-specific and change with every release:

```
# Fedora (check the release you want; owner is the Fedora project)
aws ec2 describe-images --owners 125523088429 \
  --filters 'Name=name,Values=Fedora-Cloud-Base-*-x86_64-*' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].[ImageId,Name]' --output text

# Debian (owner is the Debian project)
aws ec2 describe-images --owners 136693071363 \
  --filters 'Name=name,Values=debian-1*-amd64-*' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].[ImageId,Name]' --output text
```

Record the AMI ID you actually used alongside any result you intend to keep. A
benchmark number without the image it ran on is not reproducible.

## EC2 hygiene

Prefer stopping to terminating while you are still iterating, since a stopped
instance keeps its root volume and costs only storage, and prefer terminating
once you are done, since a stopped instance you have forgotten is still paying
for that volume.

Set `InstanceInitiatedShutdownBehavior=terminate` on genuinely disposable
instances so that a `shutdown -h now` from inside the box is a complete
teardown. For long unattended runs, put a self-destruct in the instance itself
rather than trusting yourself to remember:

```
# in user-data, as a backstop
echo 'shutdown -h +480' | at now   # 8 hours
```

Use one key pair per burner account and delete it with the account; do not
carry a long-lived key across accounts. Keep security groups narrow, which for
a benchmark box usually means SSH from your own address only, and never
`0.0.0.0/0` on anything that is not deliberately a public service. Put the work
in a VPC you created for it, so deleting the VPC is a reliable way to catch
stragglers.

Check the region you are in before you launch. Resources stranded in a region
you never look at are the most common form of forgotten spend, and a burner
account makes that easy to do by accident.

## EBS hygiene

Size the volume for the data plus headroom, not generously "to be safe", and
choose the type deliberately. `gp3` is the sensible default and lets you set
throughput and IOPS independently of size, so there is rarely a reason to
over-provision capacity just to buy performance. Use `io2` only when the
workload genuinely needs sustained low-latency IOPS, and know that you are
paying for it.

Set `DeleteOnTermination=true` for scratch volumes, which is the default for
the root volume and is not the default for volumes you attach afterwards. That
single flag is the difference between terminating an instance and leaving a
volume behind.

Detached volumes and orphaned snapshots are the classic burner-account
leftovers because nothing about them is visible from the instance list. Sweep
for them explicitly before you finish:

```
# volumes attached to nothing
aws ec2 describe-volumes --filters 'Name=status,Values=available' \
  --query 'Volumes[].[VolumeId,Size,CreateTime]' --output table

# snapshots you own
aws ec2 describe-snapshots --owner-ids self \
  --query 'Snapshots[].[SnapshotId,VolumeSize,StartTime,Description]' --output table
```

For benchmark work, remember that a fresh `gp3` volume is not warmed up and
that restoring from a snapshot lazily loads blocks on first read, so early
numbers will be pessimistic and misleading. Pre-read the volume before
measuring, or accept that the first pass is throwaway.

## What not to put in a burner account

No production data, no customer data, and no secret that exists anywhere else.
The account is shared, short-lived, and ends in a bulk deletion, which is
exactly the wrong place for anything that matters. If an experiment needs
realistic data, generate or anonymise it. If it needs a credential, mint one
scoped to that account and let it die with the account.
