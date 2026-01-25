# IAM Plan (MVP)

Lambda inference:
- s3:GetObject (artifacts/models/*)
- logs:CreateLogStream
- logs:PutLogEvents

Pipeline lambdas:
- s3:GetObject
- s3:PutObject
- states:StartExecution
- cloudwatch:PutMetricData

Step Functions:
- lambda:InvokeFunction
- logs:*

Forbidden:
- ec2:*
- rds:*
- eks:*
- sagemaker:*
