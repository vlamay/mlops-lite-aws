terraform {
  # Configure after creating the bucket.
  backend "s3" {
    bucket  = "mlops-lite-tfstate-vlad-20260124"
    key     = "state/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}

# DynamoDB table for state locking — prevents concurrent apply race conditions
# Create with: aws dynamodb create-table --table-name mlops-lite-tfstate-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST --region eu-central-1
