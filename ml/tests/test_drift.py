from ml.drift.drift import compute_drift


def test_drift_contract():
    result = compute_drift({"f1": 0.0}, {"f1": 1.0})
    assert "drift_score" in result
