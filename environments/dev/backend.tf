# Terraform backend configuration for storing state in S3
# Uncomment and configure this after creating S3 bucket and DynamoDB table
# Run: infra/scripts/setup-backend.sh first, then replace YOUR_ACCOUNT_ID below

# terraform {
#   backend "s3" {
#     bucket         = "microservices-terraform-state-YOUR_ACCOUNT_ID"
#     key            = "microservices/dev/terraform.tfstate"
#     region         = "ap-southeast-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

# To create the S3 bucket and DynamoDB table for state management:
#
# aws s3api create-bucket --bucket your-terraform-state-bucket --region us-east-1
#
# aws s3api put-bucket-versioning \
#   --bucket your-terraform-state-bucket \
#   --versioning-configuration Status=Enabled
#
# aws s3api put-bucket-encryption \
#   --bucket your-terraform-state-bucket \
#   --server-side-encryption-configuration '{
#     "Rules": [{
#       "ApplyServerSideEncryptionByDefault": {
#         "SSEAlgorithm": "AES256"
#       }
#     }]
#   }'
#
# aws dynamodb create-table \
#   --table-name terraform-state-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
#   --region us-east-1
