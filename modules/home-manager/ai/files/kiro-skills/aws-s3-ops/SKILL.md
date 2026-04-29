---
name: aws-s3-ops
description: S3 bucket operations, lifecycle policies, cross-account access, and sync patterns.
---

## Common Operations

```bash
aws s3api create-bucket --bucket my-bucket --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2
aws s3api put-bucket-tagging --bucket my-bucket \
  --tagging 'TagSet=[{Key=Owner,Value=gregburd},{Key=Purpose,Value=testing}]'
aws s3 sync ./data/ s3://my-bucket/data/ --delete
aws s3 cp file.tar.gz s3://my-bucket/ --sse AES256
```

## Lifecycle

```bash
aws s3api put-bucket-lifecycle-configuration --bucket my-bucket --lifecycle-configuration '{
  "Rules": [{"ID": "expire-test", "Status": "Enabled", "Filter": {"Prefix": "test/"}, "Expiration": {"Days": 7}}]
}'
```

## Safety

- Tag buckets: Owner, Purpose
- Enable versioning for important data
- `--dryrun` with sync/cp for preview
- Confirm account before creating
