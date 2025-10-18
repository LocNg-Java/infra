#!/bin/bash

# Script to cleanup failed resources and retry Terraform apply

set -e

echo "Cleaning up failed resources..."

# Get current AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# Clean up ECR repositories if they exist
echo "leaning up ECR repositories..."
for repo in auth-service order-service payment-service react-frontend; do
    if aws ecr describe-repositories --repository-names $repo --region us-east-1 >/dev/null 2>&1; then
        echo "Deleting ECR repository: $repo"
        aws ecr delete-repository --repository-name $repo --force --region us-east-1 || echo "Failed to delete $repo"
    fi
done

# Clean up RDS instance if it exists
echo "Cleaning up RDS instance..."
if aws rds describe-db-instances --db-instance-identifier microservices-dev-postgres --region us-east-1 >/dev/null 2>&1; then
    echo "Deleting RDS instance: microservices-dev-postgres"
    aws rds delete-db-instance \
        --db-instance-identifier microservices-dev-postgres \
        --skip-final-snapshot \
        --region us-east-1 || echo "Failed to delete RDS instance"
fi

# Clean up Secrets Manager secret if it exists
echo "Cleaning up Secrets Manager secret..."
if aws secretsmanager describe-secret --secret-id microservices-dev-rds-credentials --region us-east-1 >/dev/null 2>&1; then
    echo "Deleting secret: microservices-dev-rds-credentials"
    aws secretsmanager delete-secret --secret-id microservices-dev-rds-credentials --force-delete-without-recovery --region us-east-1 || echo "Failed to delete secret"
fi

# Clean up Terraform state
echo "Cleaning up Terraform state..."
cd environments/dev
terraform destroy -auto-approve || echo "Terraform destroy failed"

# Reinitialize Terraform
echo "Reinitializing Terraform..."
terraform init

echo "Cleanup completed. You can now run 'terraform apply' again."
