output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_secrets_manager_arn" {
  description = "ARN of Secrets Manager secret for RDS credentials"
  value       = module.rds.secrets_manager_secret_arn
}

output "alb_controller_role_arn" {
  description = "ARN of IAM role for ALB Controller"
  value       = module.iam.alb_controller_role_arn
}

output "secrets_manager_role_arn" {
  description = "ARN of IAM role for Secrets Manager access"
  value       = module.iam.secrets_manager_role_arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_id}"
}
