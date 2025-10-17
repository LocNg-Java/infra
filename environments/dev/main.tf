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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "Terraform"
      Project     = "microservices-app"
    }
  }
}

# Kubernetes provider configuration
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

locals {
  cluster_name = "eks-main-dev"
  name_prefix  = "microservices-dev"

  common_tags = {
    Environment = "dev"
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

  cluster_name            = local.cluster_name
  cluster_version         = var.eks_cluster_version
  vpc_id                  = module.vpc.vpc_id
  public_subnet_ids       = module.vpc.public_subnet_ids
  private_subnet_ids      = module.vpc.private_subnet_ids
  node_group_instance_types = var.node_group_instance_types
  node_group_desired_size = var.node_group_desired_size
  node_group_max_size     = var.node_group_max_size
  node_group_min_size     = var.node_group_min_size

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

  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  max_image_count      = 10

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
  skip_final_snapshot    = true

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

# Kubernetes Addons (Dashboard, Metrics Server)
module "k8s_addons" {
  source = "../../modules/k8s-addons"

  cluster_id             = module.eks.cluster_id
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority_data
  enable_dashboard       = true
  enable_metrics_server  = true

  depends_on = [module.eks]
}
