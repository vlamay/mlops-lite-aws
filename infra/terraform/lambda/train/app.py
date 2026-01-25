import time


def lambda_handler(event, context):
    """
    Minimal train step: returns placeholder model path and metrics.
    """
    try:
        _data = (event or {}).get("data", [])
        _ = _data  # placeholder for training input
        return {
            "statusCode": 200,
            "model_path": "model.pkl",
            "metrics": {"accuracy": 0.85},
            "request_id": context.aws_request_id,
            "ts": int(time.time()),
        }
    except Exception as exc:
        return {
            "statusCode": 500,
            "error": str(exc),
            "request_id": context.aws_request_id,
        }
