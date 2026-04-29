# AWS EC2 Lifecycle

Manage EC2 instances for testing: spin up, run tests, gather results, terminate. Use when creating test environments or running benchmarks on EC2.

## Launch Instance

```bash
# Always tag resources
aws ec2 run-instances \
  --image-id ami-XXXXXXXX \
  --instance-type t3.xlarge \
  --key-name <KEY> \
  --security-group-ids sg-XXXXXXXX \
  --subnet-id subnet-XXXXXXXX \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Owner,Value=gregburd},{Key=Purpose,Value=testing},{Key=Expiry,Value=YYYY-MM-DD}]' \
  --output json

# Prefer spot for testing (up to 90% cheaper)
aws ec2 run-instances \
  --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
  ...
```

## Wait and Connect

```bash
aws ec2 wait instance-running --instance-ids i-XXXXXXXX
IP=$(aws ec2 describe-instances --instance-ids i-XXXXXXXX --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
ssh -i ~/.ssh/<KEY>.pem ec2-user@$IP
```

## Gather Results and Terminate

```bash
scp -i ~/.ssh/<KEY>.pem ec2-user@$IP:/path/to/results ./results/
aws ec2 terminate-instances --instance-ids i-XXXXXXXX
```

## Multi-Region

```bash
# Always pass --region explicitly
aws ec2 describe-instances --region us-west-2
aws ec2 describe-instances --region eu-west-1
```

## Safety

- **Always tag** with Owner, Purpose, Expiry
- **Prefer spot** for testing workloads
- **Terminate when done** — don't leave instances running overnight
- **Dry-run first** for launch commands: `--dry-run`
- **Check costs** periodically: `aws ce get-cost-and-usage`
- **Confirm account** before launching: `aws sts get-caller-identity`
