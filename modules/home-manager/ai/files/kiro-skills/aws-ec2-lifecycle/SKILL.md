---
name: aws-ec2-lifecycle
description: Manage EC2 instances for testing. Spin up, run tests, gather results, terminate. Covers spot instances, tagging, multi-region, and cost awareness.
---

## Launch

```bash
aws ec2 run-instances --image-id ami-XXX --instance-type t3.xlarge --key-name <KEY> \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Owner,Value=gregburd},{Key=Purpose,Value=testing},{Key=Expiry,Value=YYYY-MM-DD}]'
```

Prefer spot: `--instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}'`

## Connect

```bash
aws ec2 wait instance-running --instance-ids i-XXX
IP=$(aws ec2 describe-instances --instance-ids i-XXX --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
ssh -i ~/.ssh/<KEY>.pem ec2-user@$IP
```

## Cleanup

```bash
scp -i ~/.ssh/<KEY>.pem ec2-user@$IP:/path/results ./results/
aws ec2 terminate-instances --instance-ids i-XXX
```

## Safety

- Always tag: Owner, Purpose, Expiry
- Prefer spot for testing
- Terminate when done — no overnight instances
- `--dry-run` before launch
- `aws sts get-caller-identity` before launching
- Pass `--region` explicitly
