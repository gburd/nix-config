# AWS Serverless

Deploy and manage Lambda functions, API Gateway, and Step Functions via CLI. Use when building serverless applications without CDK/CloudFormation.

## Lambda

```bash
# Create function
aws lambda create-function --function-name my-func \
  --runtime provided.al2023 --handler bootstrap \
  --role arn:aws:iam::<ACCOUNT>:role/<ROLE> \
  --zip-file fileb://target/lambda/bootstrap.zip \
  --tags Owner=gregburd,Purpose=testing

# Update code
aws lambda update-function-code --function-name my-func --zip-file fileb://bootstrap.zip

# Invoke
aws lambda invoke --function-name my-func --payload '{"key":"value"}' output.json

# View logs
aws logs tail /aws/lambda/my-func --follow
aws logs filter-log-events --log-group-name /aws/lambda/my-func --filter-pattern "ERROR"
```

## API Gateway (HTTP API)

```bash
aws apigatewayv2 create-api --name my-api --protocol-type HTTP
aws apigatewayv2 create-integration --api-id <API_ID> --integration-type AWS_PROXY \
  --integration-uri arn:aws:lambda:<REGION>:<ACCOUNT>:function:my-func
aws apigatewayv2 create-route --api-id <API_ID> --route-key 'GET /items'
aws apigatewayv2 create-stage --api-id <API_ID> --stage-name prod --auto-deploy
```

## Step Functions

```bash
aws stepfunctions create-state-machine --name my-workflow \
  --definition file://workflow.json \
  --role-arn arn:aws:iam::<ACCOUNT>:role/<ROLE>

aws stepfunctions start-execution --state-machine-arn <ARN> --input '{"key":"value"}'
aws stepfunctions describe-execution --execution-arn <EXEC_ARN>
```

## Safety

- Tag all resources: Owner, Purpose, Expiry
- Set Lambda concurrency limits for test functions
- Use `--dry-run` where available
- Clean up test functions when done
