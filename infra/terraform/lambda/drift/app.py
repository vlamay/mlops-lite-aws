import time


def lambda_handler(event, context):
    """
    Minimal drift step: returns a placeholder drift score.
    """
    try:
        _baseline = (event or {}).get("baseline", [])
        _current = (event or {}).get("current", [])
        _ = (_baseline, _current)  # placeholder for actual drift computation

        return {
            "statusCode": 200,
            "drift_score": 0.01,
            "request_id": context.aws_request_id,
            "ts": int(time.time()),
        }
    except Exception as exc:
        return {
            "statusCode": 500,
            "error": str(exc),
            "request_id": context.aws_request_id,
        }
