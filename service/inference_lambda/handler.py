import json
import os


def handler(event, context):
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(
            {
                "prediction": None,
                "model_version": os.getenv("MODEL_VERSION", "bootstrap"),
                "request_id": context.aws_request_id,
            }
        ),
    }


lambda_handler = handler
