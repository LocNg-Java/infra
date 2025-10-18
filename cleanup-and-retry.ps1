# PowerShell script to cleanup failed resources and retry Terraform apply

Write-Host "Cleaning up failed resources..." -ForegroundColor Yellow

# Get current AWS account ID
try {
    $AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
    Write-Host "AWS Account ID: $AWS_ACCOUNT_ID" -ForegroundColor Green
} catch {
    Write-Host "Error: AWS CLI not found or not configured. Please install AWS CLI and configure credentials." -ForegroundColor Red
    exit 1
}

# Clean up ECR repositories if they exist
Write-Host "Cleaning up ECR repositories..." -ForegroundColor Yellow
$repos = @("auth-service", "order-service", "payment-service", "react-frontend")
foreach ($repo in $repos) {
    try {
        aws ecr describe-repositories --repository-names $repo --region us-east-1 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Deleting ECR repository: $repo" -ForegroundColor Red
            aws ecr delete-repository --repository-name $repo --force --region us-east-1
        }
    } catch {
        Write-Host "Repository $repo does not exist or already deleted" -ForegroundColor Gray
    }
}

# Clean up RDS instance if it exists
Write-Host "Cleaning up RDS instance..." -ForegroundColor Yellow
try {
    aws rds describe-db-instances --db-instance-identifier microservices-dev-postgres --region us-east-1 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Deleting RDS instance: microservices-dev-postgres" -ForegroundColor Red
        aws rds delete-db-instance --db-instance-identifier microservices-dev-postgres --skip-final-snapshot --region us-east-1
    }
} catch {
    Write-Host "RDS instance does not exist or already deleted" -ForegroundColor Gray
}

# Clean up Secrets Manager secret if it exists
Write-Host "Cleaning up Secrets Manager secret..." -ForegroundColor Yellow
try {
    aws secretsmanager describe-secret --secret-id microservices-dev-rds-credentials --region us-east-1 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Deleting secret: microservices-dev-rds-credentials" -ForegroundColor Red
        aws secretsmanager delete-secret --secret-id microservices-dev-rds-credentials --force-delete-without-recovery --region us-east-1
    }
} catch {
    Write-Host "Secret does not exist or already deleted" -ForegroundColor Gray
}

# Clean up IAM roles if they exist
Write-Host "Cleaning up IAM roles..." -ForegroundColor Yellow
$roles = @("eks-main-dev-cluster-role", "eks-main-dev-node-group-role")
foreach ($role in $roles) {
    try {
        aws iam get-role --role-name $role 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Deleting IAM role: $role" -ForegroundColor Red
            # Detach policies first
            $policies = aws iam list-attached-role-policies --role-name $role --query 'AttachedPolicies[].PolicyArn' --output text
            foreach ($policy in $policies) {
                if ($policy -ne "None") {
                    aws iam detach-role-policy --role-name $role --policy-arn $policy
                }
            }
            aws iam delete-role --role-name $role
        }
    } catch {
        Write-Host "IAM role $role does not exist or already deleted" -ForegroundColor Gray
    }
}

# Clean up Terraform state
Write-Host "Cleaning up Terraform state..." -ForegroundColor Yellow
Set-Location environments/dev
try {
    terraform destroy -auto-approve
} catch {
    Write-Host "Terraform destroy failed or no resources to destroy" -ForegroundColor Gray
}

# Reinitialize Terraform
Write-Host "Reinitializing Terraform..." -ForegroundColor Yellow
terraform init

Write-Host "Cleanup completed. You can now run 'terraform apply' again." -ForegroundColor Green
