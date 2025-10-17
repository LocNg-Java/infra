variable "cluster_id" {
  description = "EKS cluster ID/name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "EKS cluster certificate authority data"
  type        = string
}

variable "enable_dashboard" {
  description = "Enable Kubernetes Dashboard"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Enable Metrics Server"
  type        = bool
  default     = true
}
