terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "prod"
      ManagedBy   = "Terraform"
      Project     = "microservices-app"
    }
  }
}

locals {
  cluster_name = "eks-main-prod"
  name_prefix  = "microservices-prod"

  common_tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
    Project     = "microservices-app"
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = true
  cluster_name         = local.cluster_name

  tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  cluster_name                = local.cluster_name
  cluster_version             = var.eks_cluster_version
  vpc_id                      = module.vpc.vpc_id
  public_subnet_ids           = module.vpc.public_subnet_ids
  private_subnet_ids          = module.vpc.private_subnet_ids
  node_group_instance_types   = var.node_group_instance_types
  node_group_desired_size     = var.node_group_desired_size
  node_group_max_size         = var.node_group_max_size
  node_group_min_size         = var.node_group_min_size

  tags = local.common_tags

  depends_on = [module.vpc]
}

# ECR Module
module "ecr" {
  source = "../../modules/ecr"

  repository_names = [
    "auth-service",
    "order-service",
    "payment-service",
    "react-frontend"
  ]

  image_tag_mutability = "IMMUTABLE"  # Immutable for production
  scan_on_push         = true
  max_image_count      = 20           # Keep more images in prod

  tags = local.common_tags
}

# RDS Module
module "rds" {
  source = "../../modules/rds"

  name_prefix            = local.name_prefix
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  eks_security_group_id  = module.eks.cluster_security_group_id
  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage
  database_name          = var.rds_database_name
  master_username        = var.rds_master_username
  skip_final_snapshot    = false      # Keep snapshot for production

  tags = local.common_tags

  depends_on = [module.eks]
}

# IAM Module (IRSA)
module "iam" {
  source = "../../modules/iam"

  cluster_name          = local.cluster_name
  oidc_provider_arn     = module.eks.oidc_provider_arn
  oidc_provider_url     = module.eks.cluster_oidc_issuer_url
  secrets_manager_arns  = [module.rds.secrets_manager_secret_arn]

  tags = local.common_tags

  depends_on = [module.eks, module.rds]
}
