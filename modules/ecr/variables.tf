variable "repository_names" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = ["auth-service", "order-service", "payment-service", "react-frontend"]
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository. Must be MUTABLE or IMMUTABLE"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "The encryption type to use for the repository. Valid values are AES256 or KMS"
  type        = string
  default     = "AES256"
}

variable "max_image_count" {
  description = "Maximum number of images to keep in the repository"
  type        = number
  default     = 10
}

variable "allow_pull_from_accounts" {
  description = "List of AWS account IDs to allow pulling images from"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
