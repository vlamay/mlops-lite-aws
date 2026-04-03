"""
MLOps Lite — Training Pipeline
Supports both Lambda event interface (production) and direct call interface (tests/local).
"""
import os
import json
import logging
import pickle
import tempfile
from datetime import datetime

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

S3_BUCKET = os.environ.get("S3_BUCKET", "")
MODEL_PREFIX = os.environ.get("MODEL_PREFIX", "models")


def _build_pipeline():
    return Pipeline([
        ("scaler", StandardScaler()),
        ("clf", RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42, n_jobs=-1)),
    ])


def _evaluate(model, X_test, y_test):
    y_pred = model.predict(X_test)
    return {
        "accuracy": round(float(accuracy_score(y_test, y_pred)), 4),
        "precision": round(float(precision_score(y_test, y_pred, average="weighted", zero_division=0)), 4),
        "recall": round(float(recall_score(y_test, y_pred, average="weighted", zero_division=0)), 4),
        "f1": round(float(f1_score(y_test, y_pred, average="weighted", zero_division=0)), 4),
    }


def _train_on_dataframe(df: pd.DataFrame, model_version: str) -> dict:
    """Core training logic on a pandas DataFrame."""
    feature_cols = [c for c in df.columns if c != "label"]
    X = df[feature_cols].values.astype(np.float64)
    y = df["label"].values if "label" in df.columns else np.zeros(len(df), dtype=int)

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    model = _build_pipeline()
    model.fit(X_train, y_train)
    metrics = _evaluate(model, X_test, y_test)

    model_path = f"{MODEL_PREFIX}/{model_version}/model.pkl"

    if S3_BUCKET:
        import boto3
        with tempfile.NamedTemporaryFile(suffix=".pkl") as f:
            pickle.dump(model, f)
            f.flush()
            boto3.client("s3").upload_file(f.name, S3_BUCKET, model_path)
        logger.info("Model saved to s3://%s/%s", S3_BUCKET, model_path)

    return {
        "model_path": f"s3://{S3_BUCKET}/{model_path}" if S3_BUCKET else model_path,
        "metrics": metrics,
        "train_samples": len(X_train),
        "test_samples": len(X_test),
        "model_version": model_version,
    }


def train(data, context=None):
    """
    Dual interface:
    - Lambda/Step Functions: data = {"data_key": "s3://...", "model_version": "..."}
    - Local/test: data = list of dicts [{"f1": 1.2, "f2": 3.4, "label": 0}, ...]
    """
    model_version = datetime.utcnow().strftime("%Y%m%d_%H%M%S")

    # Lambda event interface
    if isinstance(data, dict) and "data_key" in data:
        import boto3
        model_version = data.get("model_version", model_version)
        key = data["data_key"]
        with tempfile.NamedTemporaryFile(suffix=".csv") as f:
            boto3.client("s3").download_file(S3_BUCKET, key, f.name)
            df = pd.read_csv(f.name)
        return _train_on_dataframe(df, model_version)

    # Direct call interface (tests / local)
    if isinstance(data, list):
        df = pd.DataFrame(data)
        if "label" not in df.columns:
            df["label"] = 0
        return _train_on_dataframe(df, model_version)

    raise ValueError(f"Unsupported data type: {type(data)}")
