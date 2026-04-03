"""
MLOps Lite — Data Drift Detection
PSI (Population Stability Index) + KS-test for distribution shift detection.
"""
import os
import json
import logging
import tempfile

import boto3
import numpy as np
from scipy import stats

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

S3_BUCKET = os.environ["S3_BUCKET"]
PSI_THRESHOLD = float(os.environ.get("PSI_THRESHOLD", "0.2"))
KS_PVALUE_THRESHOLD = float(os.environ.get("KS_PVALUE_THRESHOLD", "0.05"))
N_BINS = int(os.environ.get("PSI_BINS", "10"))


def _load_array(key):
    s3 = boto3.client("s3")
    with tempfile.NamedTemporaryFile(suffix=".npz") as f:
        s3.download_file(S3_BUCKET, key, f.name)
        return np.load(f.name)["X"]


def compute_psi(baseline, current, n_bins=N_BINS):
    """PSI per feature, averaged. >0.2 = significant drift → retrain."""
    n_features = baseline.shape[1] if baseline.ndim > 1 else 1
    baseline = baseline.reshape(-1, n_features)
    current = current.reshape(-1, n_features)
    scores = []
    for i in range(n_features):
        bins = np.unique(np.percentile(baseline[:, i], np.linspace(0, 100, n_bins + 1)))
        if len(bins) < 2:
            continue
        b_pct = (np.histogram(baseline[:, i], bins=bins)[0] + 1e-6) / (len(baseline) + 1e-6 * n_bins)
        c_pct = (np.histogram(current[:, i], bins=bins)[0] + 1e-6) / (len(current) + 1e-6 * n_bins)
        scores.append(float(np.sum((c_pct - b_pct) * np.log(c_pct / b_pct))))
    return float(np.mean(scores)) if scores else 0.0


def compute_drift(event, context=None):
    baseline_key = event.get("baseline_key", "data/baseline/dataset.npz")
    current_key = event.get("current_key", "data/current/dataset.npz")

    baseline = _load_array(baseline_key)
    current = _load_array(current_key)

    psi = compute_psi(baseline, current)

    n_features = baseline.shape[1] if baseline.ndim > 1 else 1
    baseline = baseline.reshape(-1, n_features)
    current = current.reshape(-1, n_features)
    ks_results = {}
    for i in range(n_features):
        stat, pvalue = stats.ks_2samp(baseline[:, i], current[:, i])
        ks_results[f"feature_{i}"] = {"statistic": round(float(stat), 4), "pvalue": round(float(pvalue), 4)}

    drift_detected = psi > PSI_THRESHOLD or any(r["pvalue"] < KS_PVALUE_THRESHOLD for r in ks_results.values())
    result = {
        "drift_detected": drift_detected,
        "drift_score": round(psi, 4),
        "psi_threshold": PSI_THRESHOLD,
        "ks_tests": ks_results,
        "recommendation": "retrain" if drift_detected else "monitor",
        "baseline_samples": len(baseline),
        "current_samples": len(current),
    }
    logger.info("Drift: psi=%.4f detected=%s", psi, drift_detected)
    return result
