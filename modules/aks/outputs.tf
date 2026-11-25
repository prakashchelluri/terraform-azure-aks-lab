output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  description = "AKS cluster resource ID."
  value       = azurerm_kubernetes_cluster.this.id
}

output "resource_group_name" {
  description = "Resource group that holds the cluster."
  value       = azurerm_kubernetes_cluster.this.resource_group_name
}

output "kube_config" {
  description = "Raw kubeconfig. With azure_rbac_enabled it is an Entra ID kubeconfig and needs kubelogin."
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity federation."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID used by Container Insights."
  value       = azurerm_log_analytics_workspace.this.id
}
