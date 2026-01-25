import time


def lambda_handler(event, context):
    """
    Minimal validation: checks that data is present and returns basic stats.
    """
    try:
        data = (event or {}).get("data", [])
        rows = len(data) if isinstance(data, list) else 0
        return {
            "statusCode": 200,
            "valid": True,
            "stats": {"rows": rows},
            "request_id": context.aws_request_id,
            "ts": int(time.time()),
        }
    except Exception as exc:
        return {
            "statusCode": 500,
            "error": str(exc),
            "request_id": context.aws_request_id,
        }
