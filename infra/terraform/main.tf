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

# --- Lambda pipeline functions ---
# Validate Lambda
resource "aws_iam_role" "lambda_validate" {
  name = "mlops-lite-lambda-validate-${var.env}"
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

resource "aws_iam_policy" "lambda_validate" {
  name = "mlops-lite-lambda-validate-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.data.arn}/*"
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

resource "aws_iam_role_policy_attachment" "lambda_validate" {
  role       = aws_iam_role.lambda_validate.name
  policy_arn = aws_iam_policy.lambda_validate.arn
}

resource "aws_cloudwatch_log_group" "lambda_validate" {
  name              = "/aws/lambda/mlops-lite-validate-${var.env}"
  retention_in_days = 7
}

data "archive_file" "validate_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/validate"
  output_path = "${path.module}/.build/validate_lambda.zip"
}

resource "aws_lambda_function" "validate" {
  function_name    = "mlops-lite-validate-${var.env}"
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_validate.arn
  filename         = data.archive_file.validate_zip.output_path
  source_code_hash = data.archive_file.validate_zip.output_base64sha256

  timeout     = 60
  memory_size = 256

  environment {
    variables = {
      DATA_BUCKET = aws_s3_bucket.data.bucket
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_validate]
}

# Train Lambda
resource "aws_iam_role" "lambda_train" {
  name = "mlops-lite-lambda-train-${var.env}"
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

resource "aws_iam_policy" "lambda_train" {
  name = "mlops-lite-lambda-train-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.data.arn}/*"
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

resource "aws_iam_role_policy_attachment" "lambda_train" {
  role       = aws_iam_role.lambda_train.name
  policy_arn = aws_iam_policy.lambda_train.arn
}

resource "aws_cloudwatch_log_group" "lambda_train" {
  name              = "/aws/lambda/mlops-lite-train-${var.env}"
  retention_in_days = 7
}

data "archive_file" "train_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/train"
  output_path = "${path.module}/.build/train_lambda.zip"
}

resource "aws_lambda_function" "train" {
  function_name    = "mlops-lite-train-${var.env}"
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_train.arn
  filename         = data.archive_file.train_zip.output_path
  source_code_hash = data.archive_file.train_zip.output_base64sha256

  timeout     = 300
  memory_size = 1024

  environment {
    variables = {
      DATA_BUCKET = aws_s3_bucket.data.bucket
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_train]
}

# Publish Lambda
resource "aws_iam_role" "lambda_publish" {
  name = "mlops-lite-lambda-publish-${var.env}"
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

resource "aws_iam_policy" "lambda_publish" {
  name = "mlops-lite-lambda-publish-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:PutObjectAcl"]
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

resource "aws_iam_role_policy_attachment" "lambda_publish" {
  role       = aws_iam_role.lambda_publish.name
  policy_arn = aws_iam_policy.lambda_publish.arn
}

resource "aws_cloudwatch_log_group" "lambda_publish" {
  name              = "/aws/lambda/mlops-lite-publish-${var.env}"
  retention_in_days = 7
}

data "archive_file" "publish_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/publish"
  output_path = "${path.module}/.build/publish_lambda.zip"
}

resource "aws_lambda_function" "publish" {
  function_name    = "mlops-lite-publish-${var.env}"
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_publish.arn
  filename         = data.archive_file.publish_zip.output_path
  source_code_hash = data.archive_file.publish_zip.output_base64sha256

  timeout     = 60
  memory_size = 256

  environment {
    variables = {
      ARTIFACTS_BUCKET = aws_s3_bucket.artifacts.bucket
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_publish]
}

# Update Serving Lambda
resource "aws_iam_role" "lambda_update_serving" {
  name = "mlops-lite-lambda-update-serving-${var.env}"
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

resource "aws_iam_policy" "lambda_update_serving" {
  name = "mlops-lite-lambda-update-serving-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:GetFunctionConfiguration", "lambda:UpdateFunctionConfiguration"]
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

resource "aws_iam_role_policy_attachment" "lambda_update_serving" {
  role       = aws_iam_role.lambda_update_serving.name
  policy_arn = aws_iam_policy.lambda_update_serving.arn
}

resource "aws_cloudwatch_log_group" "lambda_update_serving" {
  name              = "/aws/lambda/mlops-lite-update-serving-${var.env}"
  retention_in_days = 7
}

data "archive_file" "update_serving_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/update-serving"
  output_path = "${path.module}/.build/update_serving_lambda.zip"
}

resource "aws_lambda_function" "update_serving" {
  function_name    = "mlops-lite-update-serving-${var.env}"
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_update_serving.arn
  filename         = data.archive_file.update_serving_zip.output_path
  source_code_hash = data.archive_file.update_serving_zip.output_base64sha256

  timeout     = 60
  memory_size = 256

  environment {
    variables = {
      INFERENCE_FUNCTION_NAME = aws_lambda_function.inference.function_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_update_serving]
}

# Drift Lambda
resource "aws_iam_role" "lambda_drift" {
  name = "mlops-lite-lambda-drift-${var.env}"
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

resource "aws_iam_policy" "lambda_drift" {
  name = "mlops-lite-lambda-drift-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${aws_s3_bucket.data.arn}/*", "${aws_s3_bucket.reports.arn}/*"]
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

resource "aws_iam_role_policy_attachment" "lambda_drift" {
  role       = aws_iam_role.lambda_drift.name
  policy_arn = aws_iam_policy.lambda_drift.arn
}

resource "aws_cloudwatch_log_group" "lambda_drift" {
  name              = "/aws/lambda/mlops-lite-drift-${var.env}"
  retention_in_days = 7
}

data "archive_file" "drift_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/drift"
  output_path = "${path.module}/.build/drift_lambda.zip"
}

resource "aws_lambda_function" "drift" {
  function_name    = "mlops-lite-drift-${var.env}"
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_drift.arn
  filename         = data.archive_file.drift_zip.output_path
  source_code_hash = data.archive_file.drift_zip.output_base64sha256

  timeout     = 120
  memory_size = 512

  environment {
    variables = {
      DATA_BUCKET    = aws_s3_bucket.data.bucket
      REPORTS_BUCKET = aws_s3_bucket.reports.bucket
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_drift]
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
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = [
          aws_lambda_function.validate.arn,
          aws_lambda_function.train.arn,
          aws_lambda_function.publish.arn,
          aws_lambda_function.update_serving.arn,
          aws_lambda_function.drift.arn,
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = aws_sfn_state_machine.train.arn
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
    validate_lambda_arn       = aws_lambda_function.validate.arn
    train_lambda_arn          = aws_lambda_function.train.arn
    publish_lambda_arn        = aws_lambda_function.publish.arn
    update_serving_lambda_arn = aws_lambda_function.update_serving.arn
  })
}

resource "aws_sfn_state_machine" "drift" {
  name     = "mlops-lite-drift-${var.env}"
  role_arn = aws_iam_role.step_functions.arn
  definition = templatefile("${path.module}/../../pipelines/drift.asl.json.tpl", {
    drift_lambda_arn        = aws_lambda_function.drift.arn
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
