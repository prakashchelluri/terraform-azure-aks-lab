output "cluster_name" {
  value = module.aks.cluster_name
}

output "resource_group_name" {
  value = module.aks.resource_group_name
}

output "oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "log_analytics_workspace_id" {
  value = module.aks.log_analytics_workspace_id
}

output "kube_config" {
  value     = module.aks.kube_config
  sensitive = true
}

output "get_credentials" {
  description = "Command that merges the cluster into your local kubeconfig."
  value       = "az aks get-credentials --resource-group ${module.aks.resource_group_name} --name ${module.aks.cluster_name}"
}
