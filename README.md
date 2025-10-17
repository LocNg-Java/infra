# Infrastructure as Code with Terraform

This directory contains Terraform configuration to provision AWS infrastructure for the microservices application.

## Architecture

The infrastructure includes:

- **VPC**: Virtual Private Cloud with public and private subnets across multiple AZs
- **EKS**: Amazon Elastic Kubernetes Service cluster with managed node groups
- **ECR**: Elastic Container Registry for Docker images (4 repos: auth, order, payment, react-frontend)
- **RDS**: PostgreSQL database for application data
- **IAM**: Roles and policies for IRSA (IAM Roles for Service Accounts)
- **Secrets Manager**: Secure storage for RDS credentials

## Directory Structure

```
infra/
├── modules/
│   ├── vpc/          # VPC, subnets, NAT gateways, route tables
│   ├── eks/          # EKS cluster, node groups, OIDC provider
│   ├── ecr/          # ECR repositories with lifecycle policies
│   ├── rds/          # RDS PostgreSQL instance with security groups
│   └── iam/          # IAM roles for ALB controller and Secrets Manager
├── environments/
│   ├── dev/          # Development environment
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── backend.tf
│   └── prod/         # Production environment
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── backend.tf
└── README.md
```

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
   ```bash
   aws configure
   ```

2. **Terraform** installed (>= 1.5)
   ```bash
   terraform version
   ```

3. **kubectl** for Kubernetes management
   ```bash
   kubectl version --client
   ```

## Usage

### Step 1: Initialize Terraform

```bash
cd infra/environments/dev
terraform init
```

### Step 2: Review the Plan

```bash
terraform plan
```

### Step 3: Apply the Configuration

```bash
terraform apply
```

This will create:
- VPC with 2 public and 2 private subnets (dev) or 3 of each (prod)
- EKS cluster `eks-main-dev` (or `eks-main-prod`)
- 4 ECR repositories
- RDS PostgreSQL instance
- IAM roles for IRSA

### Step 4: Configure kubectl

After successful apply, configure kubectl to access the EKS cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-main-dev
kubectl get nodes
```

### Step 5: Get Outputs

```bash
terraform output
```

Important outputs:
- `ecr_repository_urls` - URLs for pushing Docker images
- `eks_cluster_endpoint` - EKS cluster endpoint
- `rds_endpoint` - RDS database endpoint
- `rds_secrets_manager_arn` - ARN for database credentials
- `alb_controller_role_arn` - IAM role for ALB controller

## Environment Differences

### Dev Environment
- **Node instances**: t3.medium (2-4 nodes)
- **RDS**: db.t3.micro (20GB storage)
- **ECR**: MUTABLE tags, keep 10 images
- **AZs**: 2 availability zones
- **Final snapshot**: Skipped

### Prod Environment
- **Node instances**: t3.large (3-6 nodes)
- **RDS**: db.t3.small (50GB storage)
- **ECR**: IMMUTABLE tags, keep 20 images
- **AZs**: 3 availability zones
- **Final snapshot**: Enabled

## State Management

Uncomment the `backend.tf` configuration and create S3 bucket for remote state:

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket --bucket your-terraform-state-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

Then uncomment the backend configuration in `backend.tf` and run:

```bash
terraform init -migrate-state
```

## Cleaning Up

To destroy all infrastructure:

```bash
terraform destroy
```

**Warning**: This will delete all resources including databases. Make sure you have backups!

## Cost Estimation

Approximate monthly costs for dev environment:
- EKS cluster: ~$73/month
- EC2 nodes (2x t3.medium): ~$60/month
- RDS (db.t3.micro): ~$15/month
- NAT Gateway (2): ~$65/month
- **Total**: ~$213/month

For production, costs will be higher due to larger instances and more nodes.

## Next Steps

After infrastructure is provisioned:

1. Install ALB Ingress Controller on EKS
2. Deploy applications using Helm charts
3. Configure Route53 for DNS
4. Set up ACM certificates for HTTPS
5. Configure Harness CI/CD pipelines

## Troubleshooting

### EKS Cluster Not Accessible

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-main-dev
kubectl get svc
```

### RDS Connection Issues

Check security groups allow traffic from EKS cluster security group on port 5432.

### ECR Push Issues

Login to ECR:
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

## Support

For issues or questions, refer to:
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [RDS User Guide](https://docs.aws.amazon.com/rds/latest/UserGuide/)
