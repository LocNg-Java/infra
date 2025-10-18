resource "aws_ecr_repository" "repos" {
  for_each = toset(var.repository_names)

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
  }

  tags = merge(
    var.tags,
    {
      Name = each.value
    }
  )
}

resource "aws_ecr_lifecycle_policy" "policy" {
  for_each = toset(var.repository_names)

  repository = aws_ecr_repository.repos[each.key].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.max_image_count} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.max_image_count
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# ECR Repository Policy (optional - allows pull from EKS)
# Temporarily disabled to avoid policy format issues
# resource "aws_ecr_repository_policy" "policy" {
#   for_each = var.allow_pull_from_accounts != [] ? toset(var.repository_names) : []

#   repository = aws_ecr_repository.repos[each.key].name

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AllowPull"
#         Effect = "Allow"
#         Principal = {
#           AWS = [for account in var.allow_pull_from_accounts : "arn:aws:iam::${account}:root"]
#         }
#         Action = [
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage",
#           "ecr:BatchCheckLayerAvailability"
#         ]
#       }
#     ]
#   })
# }
