"""
MLOps Lite — Training Pipeline
Trains a RandomForest classifier on tabular data and saves model to S3.
"""
import os
import json
import logging
import pickle
import tempfile
from datetime import datetime

import boto3
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

S3_BUCKET = os.environ["S3_BUCKET"]
MODEL_PREFIX = os.environ.get("MODEL_PREFIX", "models")


def load_data_from_s3(bucket, key):
    s3 = boto3.client("s3")
    with tempfile.NamedTemporaryFile(suffix=".npz") as f:
        s3.download_file(bucket, key, f.name)
        data = np.load(f.name)
        return data["X"], data["y"]


def build_pipeline():
    return Pipeline([
        ("scaler", StandardScaler()),
        ("clf", RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42, n_jobs=-1)),
    ])


def evaluate(model, X_test, y_test):
    y_pred = model.predict(X_test)
    return {
        "accuracy": round(float(accuracy_score(y_test, y_pred)), 4),
        "precision": round(float(precision_score(y_test, y_pred, average="weighted", zero_division=0)), 4),
        "recall": round(float(recall_score(y_test, y_pred, average="weighted", zero_division=0)), 4),
        "f1": round(float(f1_score(y_test, y_pred, average="weighted", zero_division=0)), 4),
    }


def save_model_to_s3(model, version):
    s3 = boto3.client("s3")
    key = f"{MODEL_PREFIX}/{version}/model.pkl"
    with tempfile.NamedTemporaryFile(suffix=".pkl") as f:
        pickle.dump(model, f)
        f.flush()
        s3.upload_file(f.name, S3_BUCKET, key)
    logger.info("Model saved to s3://%s/%s", S3_BUCKET, key)
    return key


def train(event, context=None):
    data_key = event.get("data_key", "data/training/dataset.npz")
    model_version = event.get("model_version", datetime.utcnow().strftime("%Y%m%d_%H%M%S"))

    logger.info("Training started | data=%s version=%s", data_key, model_version)

    X, y = load_data_from_s3(S3_BUCKET, data_key)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

    model = build_pipeline()
    model.fit(X_train, y_train)
    metrics = evaluate(model, X_test, y_test)
    logger.info("Metrics: %s", json.dumps(metrics))

    model_path = save_model_to_s3(model, model_version)

    return {
        "model_version": model_version,
        "model_path": f"s3://{S3_BUCKET}/{model_path}",
        "metrics": metrics,
        "train_samples": len(X_train),
        "test_samples": len(X_test),
    }
