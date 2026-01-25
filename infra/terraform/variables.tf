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
