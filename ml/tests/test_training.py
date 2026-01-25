from ml.training.train import train


def test_training_contract():
    result = train([{"f1": 1}])
    assert "model_path" in result
    assert result["metrics"]["accuracy"] >= 0.0
