output "alb_controller_role_arn" {
  description = "ARN of IAM role for ALB Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "alb_controller_policy_arn" {
  description = "ARN of IAM policy for ALB Controller"
  value       = aws_iam_policy.alb_controller.arn
}

output "secrets_manager_role_arn" {
  description = "ARN of IAM role for Secrets Manager access"
  value       = aws_iam_role.secrets_manager.arn
}

output "secrets_manager_policy_arn" {
  description = "ARN of IAM policy for Secrets Manager access"
  value       = aws_iam_policy.secrets_manager.arn
}
