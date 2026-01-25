output "region" {
  value = var.region
}

output "api_invoke_url" {
  value = aws_apigatewayv2_stage.prod.invoke_url
}

output "data_bucket" {
  value = aws_s3_bucket.data.bucket
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}

output "reports_bucket" {
  value = aws_s3_bucket.reports.bucket
}

output "lambda_name" {
  value = aws_lambda_function.inference.function_name
}

output "train_state_machine_arn" {
  value = aws_sfn_state_machine.train.arn
}

output "drift_state_machine_arn" {
  value = aws_sfn_state_machine.drift.arn
}
