import os
import boto3


def lambda_handler(event, context):
    """
    Minimal update-serving step: updates inference Lambda env vars.
    """
    try:
        lambda_client = boto3.client("lambda")
        inference_function_name = os.getenv("INFERENCE_FUNCTION_NAME")
        if not inference_function_name:
            raise RuntimeError("INFERENCE_FUNCTION_NAME is not set")

        artifact_key = (event or {}).get("artifact_key", "models/latest/model.pkl")
        metrics = (event or {}).get("metrics", {})

        response = lambda_client.get_function_configuration(
            FunctionName=inference_function_name
        )

        current_env = response.get("Environment", {}).get("Variables", {})
        current_env["MODEL_KEY"] = artifact_key
        current_env["MODEL_VERSION"] = context.aws_request_id

        lambda_client.update_function_configuration(
            FunctionName=inference_function_name,
            Environment={"Variables": current_env},
        )

        return {
            "statusCode": 200,
            "updated_function": inference_function_name,
            "model_key": artifact_key,
            "model_version": context.aws_request_id,
            "metrics": metrics,
            "request_id": context.aws_request_id,
        }
    except Exception as exc:
        return {
            "statusCode": 500,
            "error": str(exc),
            "request_id": context.aws_request_id,
        }
