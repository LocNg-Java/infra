# Terraform backend configuration for storing state in S3
# Uncomment and configure this after creating S3 bucket and DynamoDB table

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "microservices/prod/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }
