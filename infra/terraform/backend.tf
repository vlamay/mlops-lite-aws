terraform {
  # Configure after creating the bucket.
  backend "s3" {
    bucket  = "mlops-lite-tfstate-vlad-20260124"
    key     = "state/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}
