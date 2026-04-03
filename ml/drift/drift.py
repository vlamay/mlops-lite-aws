"""
MLOps Lite — Data Drift Detection
PSI + KS-test. Supports both Lambda event and direct dict interface.
"""
import os
import json
import logging
import tempfile

import numpy as np
from scipy import stats

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

S3_BUCKET = os.environ.get("S3_BUCKET", "")
PSI_THRESHOLD = float(os.environ.get("PSI_THRESHOLD", "0.2"))
KS_PVALUE_THRESHOLD = float(os.environ.get("KS_PVALUE_THRESHOLD", "0.05"))


def _psi(baseline_arr, current_arr, n_bins=10):
    bins = np.unique(np.percentile(baseline_arr, np.linspace(0, 100, n_bins + 1)))
    if len(bins) < 2:
        return 0.0
    b = (np.histogram(baseline_arr, bins=bins)[0] + 1e-6) / (len(baseline_arr) + 1e-6 * n_bins)
    c = (np.histogram(current_arr, bins=bins)[0] + 1e-6) / (len(current_arr) + 1e-6 * n_bins)
    return float(np.sum((c - b) * np.log(c / b)))


def _dict_to_array(d: dict) -> np.ndarray:
    """Convert feature dict like {'f1': 1.0, 'f2': 2.0} to numpy array."""
    return np.array(list(d.values()), dtype=np.float64)


def compute_drift(baseline, current, context=None):
    """
    Dual interface:
    - Lambda: baseline = {"baseline_key": "s3-key", "current_key": "s3-key"}
    - Direct/test: baseline = {"f1": val, ...}, current = {"f1": val, ...}
    """
    # Lambda event interface
    if isinstance(baseline, dict) and "baseline_key" in baseline:
        import boto3
        s3 = boto3.client("s3")
        def load(key):
            with tempfile.NamedTemporaryFile(suffix=".npz") as f:
                s3.download_file(S3_BUCKET, key, f.name)
                return np.load(f.name)["X"]
        b_arr = load(baseline["baseline_key"])
        c_arr = load(baseline.get("current_key", ""))
    # Direct dict interface (tests)
    elif isinstance(baseline, dict) and isinstance(current, dict):
        b_arr = _dict_to_array(baseline).reshape(-1, 1)
        c_arr = _dict_to_array(current).reshape(-1, 1)
    else:
        raise ValueError("Unsupported arguments")

    n_features = b_arr.shape[1] if b_arr.ndim > 1 else 1
    b_arr = b_arr.reshape(-1, n_features)
    c_arr = c_arr.reshape(-1, n_features)

    psi_scores = [_psi(b_arr[:, i], c_arr[:, i]) for i in range(n_features)]
    psi = float(np.mean(psi_scores))

    ks_results = {}
    for i in range(n_features):
        stat, pvalue = stats.ks_2samp(b_arr[:, i], c_arr[:, i])
        ks_results[f"feature_{i}"] = {"statistic": round(float(stat), 4), "pvalue": round(float(pvalue), 4)}

    drift_detected = psi > PSI_THRESHOLD or any(r["pvalue"] < KS_PVALUE_THRESHOLD for r in ks_results.values())

    return {
        "drift_detected": drift_detected,
        "drift_score": round(psi, 4),
        "psi_threshold": PSI_THRESHOLD,
        "ks_tests": ks_results,
        "recommendation": "retrain" if drift_detected else "monitor",
    }
