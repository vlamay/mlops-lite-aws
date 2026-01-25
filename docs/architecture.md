# Architecture

## Decisions
- Serverless for cost control and zero idle compute.
- Step Functions for explicit, auditable orchestration.
- No EKS/SageMaker to avoid always-on costs and complexity.

## Quality Gates
- Model evaluation checks accuracy threshold before publish.
- Drift decision triggers retrain only above threshold.

## Cost Controls
- S3 lifecycle policies for reports.
- CloudWatch logs retention fixed to 7 days.
- Single region deployment.
