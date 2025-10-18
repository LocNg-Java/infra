#!/bin/bash
set -e

# Configuration
REGION="ap-southeast-1"
BUCKET_NAME="microservices-terraform-state-${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
DYNAMODB_TABLE="terraform-state-lock"

echo "Setting up Terraform backend in region: $REGION"
echo "Bucket name: $BUCKET_NAME"

# Create S3 bucket for Terraform state
echo "Creating S3 bucket..."
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

# Enable versioning on the bucket
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled \
  --region "$REGION"

# Enable encryption
echo "Enabling encryption..."
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
echo "Creating DynamoDB table for state locking..."
aws dynamodb create-table \
  --table-name "$DYNAMODB_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo ""
echo "Backend setup complete!"
echo ""
echo "Update your backend.tf files with:"
echo "  bucket = \"$BUCKET_NAME\""
echo "  region = \"$REGION\""
echo "  dynamodb_table = \"$DYNAMODB_TABLE\""