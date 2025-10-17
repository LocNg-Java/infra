output "dashboard_token_command" {
  description = "Command to get dashboard admin token"
  value       = "kubectl -n kubernetes-dashboard create token dashboard-admin"
}

output "dashboard_proxy_command" {
  description = "Command to access dashboard via kubectl proxy"
  value       = "kubectl proxy"
}

output "dashboard_url" {
  description = "Dashboard URL (after running kubectl proxy)"
  value       = "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
}

output "dashboard_admin_service_account" {
  description = "Dashboard admin service account name"
  value       = kubernetes_service_account.dashboard_admin.metadata[0].name
}
