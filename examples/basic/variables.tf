variable "name" {
  description = "Base name for the cluster and its resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to create for the lab."
  type        = string
}

variable "network_plugin" {
  description = "azure or kubenet."
  type        = string
  default     = "azure"
}

variable "system_node_pool" {
  description = "System node pool settings (see the module for fields)."
  type        = any
  default     = {}
}

variable "user_node_pool" {
  description = "Optional autoscaling user node pool (see the module for fields)."
  type        = any
  default     = {}
}

variable "azure_rbac_enabled" {
  description = "Use Entra ID with Azure RBAC for Kubernetes authorization."
  type        = bool
  default     = false
}

variable "admin_group_object_ids" {
  description = "Entra ID group object IDs that get cluster admin when azure_rbac_enabled is true."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags for every resource."
  type        = map(string)
  default     = {}
}
