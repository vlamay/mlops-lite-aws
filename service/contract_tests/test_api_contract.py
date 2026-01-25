import os
import json
import urllib.request


def test_predict_contract():
    api_url = os.getenv("API_URL")
    if not api_url:
        return

    data = json.dumps({"features": [1, 2, 3]}).encode("utf-8")
    req = urllib.request.Request(
        f"{api_url}/predict",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        payload = json.loads(resp.read().decode("utf-8"))

    assert "prediction" in payload
    assert "model_version" in payload
    assert "request_id" in payload
