variable "region" {
  type        = string
  description = "AWS region"
}

variable "project" {
  type        = string
  description = "Project tag"
  default     = "mlops-lite"
}

variable "env" {
  type        = string
  description = "Environment tag"
  default     = "dev"
}

variable "owner" {
  type        = string
  description = "Owner tag"
}

variable "bucket_suffix" {
  type        = string
  description = "Unique suffix for S3 buckets"
}

variable "model_key" {
  type        = string
  description = "S3 key for model artifact"
  default     = "models/latest/model.pkl"
}

variable "drift_schedule" {
  type        = string
  description = "EventBridge schedule expression"
  default     = "rate(1 day)"
}

variable "validate_lambda_arn" {
  type        = string
  description = "ARN for ValidateData lambda"
  default     = "arn:aws:lambda:eu-central-1:000000000000:function:mlops-lite-validate-dev"
}

variable "train_lambda_arn" {
  type        = string
  description = "ARN for TrainModel lambda"
  default     = "arn:aws:lambda:eu-central-1:000000000000:function:mlops-lite-train-dev"
}

variable "publish_lambda_arn" {
  type        = string
  description = "ARN for PublishArtifacts lambda"
  default     = "arn:aws:lambda:eu-central-1:000000000000:function:mlops-lite-publish-dev"
}

variable "update_serving_lambda_arn" {
  type        = string
  description = "ARN for UpdateServing lambda"
  default     = "arn:aws:lambda:eu-central-1:000000000000:function:mlops-lite-update-serving-dev"
}

variable "drift_lambda_arn" {
  type        = string
  description = "ARN for Drift lambda"
  default     = "arn:aws:lambda:eu-central-1:000000000000:function:mlops-lite-drift-dev"
}
