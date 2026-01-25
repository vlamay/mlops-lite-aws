import json
import os
import boto3


def lambda_handler(event, context):
    """
    Minimal publish step: writes placeholder metadata to S3.
    """
    try:
        s3_client = boto3.client("s3")
        artifacts_bucket = os.getenv("ARTIFACTS_BUCKET")
        if not artifacts_bucket:
            raise RuntimeError("ARTIFACTS_BUCKET is not set")

        model_path = (event or {}).get("model_path", "model.pkl")
        metrics = (event or {}).get("metrics", {})

        artifact_key = f"models/latest/{model_path}"
        metadata = {
            "metrics": metrics,
            "model_path": model_path,
            "timestamp": context.aws_request_id,
        }

        s3_client.put_object(
            Bucket=artifacts_bucket,
            Key=artifact_key,
            Body=json.dumps(metadata),
            ContentType="application/json",
        )

        return {
            "statusCode": 200,
            "artifact_bucket": artifacts_bucket,
            "artifact_key": artifact_key,
            "metrics": metrics,
            "request_id": context.aws_request_id,
        }
    except Exception as exc:
        return {
            "statusCode": 500,
            "error": str(exc),
            "request_id": context.aws_request_id,
        }
