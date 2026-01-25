from ml.validation.validate import validate


def test_validation_contract():
    result = validate([{"f1": 1}])
    assert result["valid"] is True
    assert "rows" in result["stats"]
