# AWS S3 Operations

Bucket operations, lifecycle policies, cross-account access, and sync patterns.

## Common Operations

```bash
# Create bucket with tags
aws s3api create-bucket --bucket my-bucket --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2
aws s3api put-bucket-tagging --bucket my-bucket \
  --tagging 'TagSet=[{Key=Owner,Value=gregburd},{Key=Purpose,Value=testing}]'

# Sync local directory to S3
aws s3 sync ./data/ s3://my-bucket/data/ --delete

# Copy with server-side encryption
aws s3 cp file.tar.gz s3://my-bucket/ --sse AES256

# List with filtering
aws s3api list-objects-v2 --bucket my-bucket --prefix data/ --query 'Contents[?Size>`1000000`]'
```

## Lifecycle Policy

```bash
aws s3api put-bucket-lifecycle-configuration --bucket my-bucket --lifecycle-configuration '{
  "Rules": [{"ID": "expire-test-data", "Status": "Enabled",
    "Filter": {"Prefix": "test/"}, "Expiration": {"Days": 7}}]
}'
```

## Cross-Account Access

```bash
# Bucket policy for cross-account read
aws s3api put-bucket-policy --bucket my-bucket --policy '{
  "Statement": [{"Effect": "Allow", "Principal": {"AWS": "arn:aws:iam::<OTHER_ACCOUNT>:root"},
    "Action": ["s3:GetObject"], "Resource": "arn:aws:s3:::my-bucket/*"}]
}'
```

## Safety

- Tag buckets: Owner, Purpose
- Enable versioning for important data: `aws s3api put-bucket-versioning --bucket my-bucket --versioning-configuration Status=Enabled`
- Use `--dryrun` with sync/cp for preview
- Confirm account before creating buckets
