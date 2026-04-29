---
name: aws-serverless
description: Deploy Lambda functions, API Gateway, and Step Functions via CLI. Use when building serverless applications without CDK/CloudFormation.
---

## Lambda

```bash
aws lambda create-function --function-name my-func --runtime provided.al2023 --handler bootstrap \
  --role arn:aws:iam::<ACCOUNT>:role/<ROLE> --zip-file fileb://bootstrap.zip \
  --tags Owner=gregburd,Purpose=testing
aws lambda update-function-code --function-name my-func --zip-file fileb://bootstrap.zip
aws lambda invoke --function-name my-func --payload '{"key":"value"}' output.json
aws logs tail /aws/lambda/my-func --follow
```

## API Gateway (HTTP API)

```bash
aws apigatewayv2 create-api --name my-api --protocol-type HTTP
aws apigatewayv2 create-integration --api-id <ID> --integration-type AWS_PROXY --integration-uri <LAMBDA_ARN>
```

## Step Functions

```bash
aws stepfunctions create-state-machine --name my-workflow --definition file://workflow.json --role-arn <ROLE_ARN>
aws stepfunctions start-execution --state-machine-arn <ARN> --input '{"key":"value"}'
```

## Safety

- Tag all resources: Owner, Purpose, Expiry
- Set Lambda concurrency limits for test functions
- Clean up test functions when done
