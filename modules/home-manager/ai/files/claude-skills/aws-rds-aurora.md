# AWS RDS/Aurora

Create and manage RDS/Aurora database clusters. Use when setting up databases, managing connections, snapshots, or parameter groups.

## Create Aurora Cluster

```bash
aws rds create-db-cluster \
  --db-cluster-identifier test-cluster \
  --engine aurora-postgresql \
  --engine-version 16.1 \
  --master-username admin \
  --master-user-password <PASSWORD> \
  --vpc-security-group-ids sg-XXX \
  --tags Key=Owner,Value=gregburd Key=Purpose,Value=testing Key=Expiry,Value=YYYY-MM-DD

aws rds create-db-instance \
  --db-instance-identifier test-instance-1 \
  --db-cluster-identifier test-cluster \
  --engine aurora-postgresql \
  --db-instance-class db.r6g.large
```

## Connection

```bash
# Get endpoint
aws rds describe-db-clusters --db-cluster-identifier test-cluster \
  --query 'DBClusters[0].Endpoint' --output text

# Connect via psql
psql -h <endpoint> -U admin -d postgres
```

## Snapshots

```bash
aws rds create-db-cluster-snapshot --db-cluster-identifier test-cluster --db-cluster-snapshot-identifier snap-$(date +%Y%m%d)
aws rds describe-db-cluster-snapshots --db-cluster-identifier test-cluster
aws rds delete-db-cluster-snapshot --db-cluster-snapshot-identifier <SNAP_ID>
```

## Cleanup

```bash
aws rds delete-db-instance --db-instance-identifier test-instance-1 --skip-final-snapshot
aws rds delete-db-cluster --db-cluster-identifier test-cluster --skip-final-snapshot
```

## Safety

- Always tag with Owner, Purpose, Expiry
- Use `--skip-final-snapshot` only for test clusters
- Never store passwords in scripts — use Secrets Manager or parameter store
- Confirm account before creating: `aws sts get-caller-identity`
