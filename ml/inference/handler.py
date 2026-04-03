"""
MLOps Lite — Inference Lambda Handler
Loads model from S3 and serves real predictions.
"""
import os, json, logging, pickle, tempfile
import boto3
import numpy as np

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

S3_BUCKET = os.environ["S3_BUCKET"]
MODEL_PREFIX = os.environ.get("MODEL_PREFIX", "models")

_model = None
_loaded_version = None

def _load_model(version):
    global _model, _loaded_version
    if _model is not None and _loaded_version == version:
        return _model
    s3 = boto3.client("s3")
    key = f"{MODEL_PREFIX}/{version}/model.pkl"
    logger.info("Loading model s3://%s/%s", S3_BUCKET, key)
    with tempfile.NamedTemporaryFile(suffix=".pkl") as f:
        s3.download_file(S3_BUCKET, key, f.name)
        _model = pickle.load(f)
        _loaded_version = version
    return _model

def handler(event, context=None):
    version = os.environ.get("MODEL_VERSION", "latest")
    try:
        body = json.loads(event["body"]) if "body" in event and isinstance(event.get("body"), str) else event.get("body", event)
        features = body.get("features")
        if features is None:
            raise ValueError("Request body must contain 'features' key")
        X = np.array(features, dtype=np.float64).reshape(1, -1) if np.array(features).ndim == 1 else np.array(features, dtype=np.float64)
        model = _load_model(version)
        predictions = model.predict(X).tolist()
        response = {"predictions": predictions, "model_version": version}
        if hasattr(model, "predict_proba"):
            response["probabilities"] = model.predict_proba(X).tolist()
        return {"statusCode": 200, "headers": {"Content-Type": "application/json"}, "body": json.dumps(response)} if "body" in event else response
    except ValueError as e:
        logger.warning("Bad request: %s", e)
        return {"statusCode": 400, "body": json.dumps({"error": str(e)})} if "body" in event else (_ for _ in ()).throw(e)
    except Exception as e:
        logger.error("Inference error: %s", e, exc_info=True)
        return {"statusCode": 500, "body": json.dumps({"error": "Internal error"})} if "body" in event else (_ for _ in ()).throw(e)
