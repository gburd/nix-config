---
name: cleanup
description: Clean up after yourself before declaring a task done. Remove everything your task created that is no longer needed, on this host and on every other host and cloud account you touched: git worktrees and their branches, files under /scratch/<proj>/ and /tmp, core files, build trees, stray processes and services, and EC2 instances, volumes, snapshots, key pairs and security groups. Use at the end of every task that created files or resources, when handing off, before saying "done", and whenever the user says "clean up", "tidy up", "remove leftovers", "reclaim disk", "what did you leave behind", or "are there EC2 instances still running". Delete only what YOUR task created.
---

# Cleanup

Leave every host and account as clean as you found it. Disk is finite,
`/scratch` is shared, and cloud resources cost money by the hour. The
person who created something is the only one who knows it is safe to
delete, so if you made it, removing it is your job. Nobody else will.

## The one rule that matters: only what you created

Before deleting anything, be able to say how you know it is yours:

- you created it in this task (you have the command in your history), or
- its path or name carries your task's purpose tag (`wt-<purpose>`,
  `scratch-<purpose>`), or
- its cloud tags say `Owner=<you>` and `Purpose=<this task>`.

If you can't say, **leave it and list it for the user**. Other agents work
in parallel on the same repositories and hosts. `git worktree list`
shows their worktrees too, and `/scratch` holds their files. Deleting
another agent's live work is far worse than leaving clutter.

Keep the teardown command next to the creation command as you work. That
is the cheapest way to know, at the end, exactly what to remove.

## Checklist

Work through every item that applies. Report what you removed and what
you deliberately kept, with the reason.

### 1. Save what matters first

Commit, push or merge the work, or record exactly where it stopped. Copy
untracked notes, logs or evidence worth keeping into the repository, the
project's `.agent/`, or its docs. Copy results off any remote host
before you tear it down. Once it is saved, nothing below loses work.

### 2. Git worktrees and branches

```sh
git -C <repo> worktree list                 # find yours by path / purpose
git -C <repo> worktree remove <path>        # --force only if you're sure
git -C <repo> worktree prune
git -C <repo> branch -d <branch>            # only once merged; -D is a decision, not a habit
```

Worktrees belong in `/scratch/<proj>/wt-<purpose>` (see workflow steering).
Check for ones left in the legacy `<project>/.local/worktrees/` too.

### 3. Files on disk

- **`/scratch/<proj>/`**: your `scratch-<purpose>/` trees, data
  directories, logs, bench output, sub-agent prompts.
- **`/tmp`**: anything you put there. `ls -la /tmp | grep $USER` and remove
  your own entries.
- **Build output** you produced and don't need for a repro: `target/`,
  `build*/`, `dist/`, `result*` symlinks (each one is a Nix GC root that
  pins store paths), generated database clusters (stop the server first:
  `pg_ctl -D <dir> stop`).

Recursive `rm` is blocked by the sandbox. Use `find <dir> -user "$USER"
-delete` (add `-mindepth 1` to keep `<dir>`), or `trash` / `gio trash`
outside `/tmp`. `find -type f -delete` leaves symlinks; `-mindepth 1
-delete` does not. `gio trash` only moves files, so space comes back
when Trash is emptied.

### 4. Core files

Delete every core you produced once you have the backtrace you needed.
Keep one only if you are still debugging that crash, and then put it in
`/scratch/<proj>/cores/` with a note naming its exact binary. Confirm a
candidate is a core before deleting it, and that nothing has it open:

```sh
find <dirs-you-worked-in> -xdev -type f \( -name core -o -name 'core.[0-9]*' -o -name '*.core' \) \
  -exec sh -c 'file -b "$1" | grep -q "core file" && ! fuser -s "$1" 2>/dev/null && echo "$1"' _ {} \;
```

Look in the directories your crashing processes ran in. Hosts that use
systemd-coredump (arnold) write compressed cores to
`/var/lib/systemd/coredump/` instead. They are owned by root, and
`systemd-tmpfiles` deletes them after two weeks (arnold: 58 files, 1.1 GiB on
2026-10-16), so there is nothing to delete by hand.
List them with `coredumpctl list` and debug with `coredumpctl debug <pid>`.
`coredumpctl` has no delete command.

### 5. Processes and services

Stop what you started and no longer need:

- background servers (postgres, test daemons);
- `systemd-run --user` units and `nohup` jobs;
- tmux/screen sessions;
- port-forwards and `ssh -fN` tunnels;
- containers (`podman ps`, `docker ps`);
- lingering `ssh` ControlMaster sockets for hosts you won't use again
  (`ssh -O exit <host>`).

Find your own with `ps -u "$USER" -o pid,etime,args` and match on what you
launched. Do not use `pkill -f <pattern>`: it can match the shell running
it. Kill by PID.

### 6. Other hosts you used

Repeat steps 2–5 on every host the task touched: lixr, sun, nuc, rv,
arnold, meh, wixa, EC2 boxes. Remote copies of worktrees conventionally sit
under `~/wt/<purpose>`. Remote cores land wherever that host's
`core_pattern` says. If you staged a credential or key file on a host,
remove it.

### 7. EC2 and other cloud resources

Check every region you used, not just the default. Stranded resources in
a region nobody looks at are the most common forgotten spend.

```sh
R=<region>
aws ec2 describe-instances --region $R --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,LaunchTime,Tags[?Key==`Name`].Value|[0],Tags[?Key==`Owner`].Value|[0]]' --output table
aws ec2 describe-volumes   --region $R --filters Name=status,Values=available --query 'Volumes[].[VolumeId,Size,CreateTime]' --output table
aws ec2 describe-snapshots --region $R --owner-ids self --query 'Snapshots[].[SnapshotId,VolumeSize,StartTime,Description]' --output table
aws ec2 describe-key-pairs --region $R --query 'KeyPairs[].[KeyName,CreateTime]' --output table
aws ec2 describe-addresses --region $R --query 'Addresses[?AssociationId==null].[PublicIp,AllocationId]' --output table
```

Terminate instances, delete detached volumes, snapshots, unassociated
Elastic IPs (billed while idle), key pairs and security groups that your
task created. Match by tag. Never terminate an instance you did not
launch. Copy results off first. Instances made by `agent-sandbox --tier
ec2` are named `asx-<workspace>`; tear those down with `agent-sandbox --tier
ec2 down <workspace> --terminate`, which also removes their key pair and
security group.

Other paid things count too: fly.io machines and IPs, DNS records, tunnels
and API keys you minted.

### 8. Verify, then report

Re-run the listing commands and confirm your items are gone. Then tell the
user, in a few lines:

- what you removed, and how much space or which resources;
- what you kept on purpose, and why;
- anything that looked abandoned but wasn't yours, left for them to
  decide.

Don't claim a clean slate you didn't check.
