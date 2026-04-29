---
name: aws-rds-aurora
description: Create and manage RDS/Aurora database clusters. Covers creation, connections, parameter groups, snapshots, and cleanup.
---

## Create Aurora Cluster

```bash
aws rds create-db-cluster --db-cluster-identifier test-cluster --engine aurora-postgresql \
  --engine-version 16.1 --master-username admin --master-user-password <PASSWORD> \
  --tags Key=Owner,Value=gregburd Key=Purpose,Value=testing Key=Expiry,Value=YYYY-MM-DD

aws rds create-db-instance --db-instance-identifier test-instance-1 \
  --db-cluster-identifier test-cluster --engine aurora-postgresql --db-instance-class db.r6g.large
```

## Connect

```bash
ENDPOINT=$(aws rds describe-db-clusters --db-cluster-identifier test-cluster --query 'DBClusters[0].Endpoint' --output text)
psql -h $ENDPOINT -U admin -d postgres
```

## Cleanup

```bash
aws rds delete-db-instance --db-instance-identifier test-instance-1 --skip-final-snapshot
aws rds delete-db-cluster --db-cluster-identifier test-cluster --skip-final-snapshot
```

## Safety

- Always tag: Owner, Purpose, Expiry
- `--skip-final-snapshot` only for test clusters
- Never store passwords in scripts
- Confirm account first: `aws sts get-caller-identity`
