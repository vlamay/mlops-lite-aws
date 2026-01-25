locals {
  data_bucket_name      = "mlops-lite-data-${var.bucket_suffix}"
  artifacts_bucket_name = "mlops-lite-artifacts-${var.bucket_suffix}"
  reports_bucket_name   = "mlops-lite-reports-${var.bucket_suffix}"
}

# --- S3 buckets ---
resource "aws_s3_bucket" "data" {
  bucket = local.data_bucket_name
}

resource "aws_s3_bucket" "artifacts" {
  bucket = local.artifacts_bucket_name
}

resource "aws_s3_bucket" "reports" {
  bucket = local.reports_bucket_name
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket                  = aws_s3_bucket.reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    id     = "expire-reports"
    status = "Enabled"
    expiration {
      days = 30
    }
  }
}

# --- Lambda inference ---
resource "aws_iam_role" "lambda_inference" {
  name = "mlops-lite-lambda-inference-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_inference" {
  name = "mlops-lite-lambda-inference-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.artifacts.arn}/models/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_inference" {
  role       = aws_iam_role.lambda_inference.name
  policy_arn = aws_iam_policy.lambda_inference.arn
}

resource "aws_cloudwatch_log_group" "lambda_inference" {
  name              = "/aws/lambda/mlops-lite-inference-${var.env}"
  retention_in_days = 7
}

data "archive_file" "inference_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../service/inference_lambda"
  output_path = "${path.module}/.build/inference_lambda.zip"
}

resource "aws_lambda_function" "inference" {
  function_name    = "mlops-lite-inference-${var.env}"
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_inference.arn
  filename         = data.archive_file.inference_zip.output_path
  source_code_hash = data.archive_file.inference_zip.output_base64sha256

  timeout     = 15
  memory_size = 512

  environment {
    variables = {
      MODEL_BUCKET  = aws_s3_bucket.artifacts.bucket
      MODEL_KEY     = var.model_key
      MODEL_VERSION = "latest"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_inference]
}

# --- API Gateway HTTP API ---
resource "aws_apigatewayv2_api" "http_api" {
  name          = "mlops-lite-http-api-${var.env}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.inference.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "predict" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /predict"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "prod"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inference.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# --- Step Functions ---
resource "aws_iam_role" "step_functions" {
  name = "mlops-lite-stepfunctions-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "step_functions" {
  name = "mlops-lite-stepfunctions-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.inference.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "step_functions" {
  role       = aws_iam_role.step_functions.name
  policy_arn = aws_iam_policy.step_functions.arn
}

resource "aws_sfn_state_machine" "train" {
  name     = "mlops-lite-train-${var.env}"
  role_arn = aws_iam_role.step_functions.arn
  definition = templatefile("${path.module}/../../pipelines/train.asl.json.tpl", {
    validate_lambda_arn       = var.validate_lambda_arn
    train_lambda_arn          = var.train_lambda_arn
    publish_lambda_arn        = var.publish_lambda_arn
    update_serving_lambda_arn = var.update_serving_lambda_arn
  })
}

resource "aws_sfn_state_machine" "drift" {
  name     = "mlops-lite-drift-${var.env}"
  role_arn = aws_iam_role.step_functions.arn
  definition = templatefile("${path.module}/../../pipelines/drift.asl.json.tpl", {
    drift_lambda_arn        = var.drift_lambda_arn
    train_state_machine_arn = aws_sfn_state_machine.train.arn
  })
}

# --- EventBridge schedule ---
resource "aws_iam_role" "eventbridge" {
  name = "mlops-lite-eventbridge-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "eventbridge" {
  name = "mlops-lite-eventbridge-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = aws_sfn_state_machine.drift.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eventbridge" {
  role       = aws_iam_role.eventbridge.name
  policy_arn = aws_iam_policy.eventbridge.arn
}

resource "aws_cloudwatch_event_rule" "drift" {
  name                = "mlops-lite-drift-schedule-${var.env}"
  schedule_expression = var.drift_schedule
}

resource "aws_cloudwatch_event_target" "drift" {
  rule     = aws_cloudwatch_event_rule.drift.name
  arn      = aws_sfn_state_machine.drift.arn
  role_arn = aws_iam_role.eventbridge.arn
}

# --- CloudWatch alarms ---
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "mlops-lite-lambda-errors-${var.env}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1

  dimensions = {
    FunctionName = aws_lambda_function.inference.function_name
  }
}
