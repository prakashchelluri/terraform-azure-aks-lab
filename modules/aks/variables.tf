variable "name" {
  description = "Base name for the cluster and its supporting resources. Also used as the DNS prefix."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,38}[a-z0-9]$", var.name))
    error_message = "The name must be 3-40 characters of lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "location" {
  description = "Azure region, for example westeurope."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.location))
    error_message = "The location must be a region name such as westeurope or eastus2 (lowercase, no spaces)."
  }
}

variable "resource_group_name" {
  description = "Resource group to deploy into. Created when create_resource_group is true, otherwise it must already exist."
  type        = string

  validation {
    condition     = can(regex("^[-\\w.()]{0,89}[-\\w()]$", var.resource_group_name))
    error_message = "The resource_group_name must be 1-90 characters of letters, digits, hyphen, underscore, period or parentheses, and must not end with a period."
  }
}

variable "create_resource_group" {
  description = "Create the resource group. Set to false to deploy into an existing one."
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "Kubernetes version such as 1.33. null uses the AKS default for the region."
  type        = string
  default     = null

  validation {
    condition     = var.kubernetes_version == null || can(regex("^1\\.[0-9]+(\\.[0-9]+)?$", var.kubernetes_version))
    error_message = "The kubernetes_version must look like 1.33 or 1.33.2, or be null."
  }
}

variable "network_plugin" {
  description = "azure (Azure CNI, pods get VNet IPs) or kubenet (pods use pod_cidr behind node NAT)."
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "kubenet"], var.network_plugin)
    error_message = "The network_plugin must be azure or kubenet."
  }
}

variable "vnet_address_space" {
  description = "Address space of the cluster VNet."
  type        = string
  default     = "10.240.0.0/16"

  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "The vnet_address_space must be a valid CIDR block."
  }
}

variable "subnet_address_prefix" {
  description = "Node subnet inside the VNet. With Azure CNI every pod also takes an IP from it, so keep it large."
  type        = string
  default     = "10.240.0.0/20"

  validation {
    condition     = can(cidrhost(var.subnet_address_prefix, 0))
    error_message = "The subnet_address_prefix must be a valid CIDR block."
  }
}

variable "service_cidr" {
  description = "Kubernetes service CIDR. Must not overlap the VNet."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.service_cidr, 0))
    error_message = "The service_cidr must be a valid CIDR block."
  }
}

variable "dns_service_ip" {
  description = "Cluster DNS service IP. Must be inside service_cidr."
  type        = string
  default     = "10.0.0.10"

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.dns_service_ip))
    error_message = "The dns_service_ip must be an IPv4 address."
  }
}

variable "pod_cidr" {
  description = "Pod CIDR, used only with kubenet. Must not overlap the VNet or service_cidr."
  type        = string
  default     = "10.244.0.0/16"

  validation {
    condition     = can(cidrhost(var.pod_cidr, 0))
    error_message = "The pod_cidr must be a valid CIDR block."
  }
}

variable "system_node_pool" {
  description = "System node pool. When the user pool is enabled, this pool only runs critical add-ons."
  type = object({
    vm_size         = optional(string, "Standard_B2s")
    node_count      = optional(number, 1)
    os_disk_size_gb = optional(number, 64)
  })
  default = {}

  validation {
    condition     = var.system_node_pool.node_count >= 1 && var.system_node_pool.node_count <= 10
    error_message = "The system_node_pool.node_count must be between 1 and 10."
  }

  validation {
    condition     = var.system_node_pool.os_disk_size_gb >= 30 && var.system_node_pool.os_disk_size_gb <= 2048
    error_message = "The system_node_pool.os_disk_size_gb must be between 30 and 2048."
  }
}

variable "user_node_pool" {
  description = "Optional autoscaling user node pool for workloads."
  type = object({
    enabled         = optional(bool, false)
    vm_size         = optional(string, "Standard_B2s")
    min_count       = optional(number, 0)
    max_count       = optional(number, 3)
    os_disk_size_gb = optional(number, 64)
  })
  default = {}

  validation {
    condition = (
      var.user_node_pool.min_count >= 0 &&
      var.user_node_pool.max_count >= 1 &&
      var.user_node_pool.min_count <= var.user_node_pool.max_count &&
      var.user_node_pool.max_count <= 20
    )
    error_message = "The user_node_pool needs 0 <= min_count <= max_count <= 20 and max_count >= 1."
  }

  validation {
    condition     = var.user_node_pool.os_disk_size_gb >= 30 && var.user_node_pool.os_disk_size_gb <= 2048
    error_message = "The user_node_pool.os_disk_size_gb must be between 30 and 2048."
  }
}

variable "azure_rbac_enabled" {
  description = "Use Microsoft Entra ID with Azure RBAC for Kubernetes authorization instead of plain Kubernetes RBAC."
  type        = bool
  default     = false
}

variable "admin_group_object_ids" {
  description = "Entra ID group object IDs granted cluster admin. Used only when azure_rbac_enabled is true."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for id in var.admin_group_object_ids :
      can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", id))
    ])
    error_message = "The admin_group_object_ids must all be GUIDs."
  }
}

variable "log_retention_days" {
  description = "Log Analytics workspace retention in days."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "The log_retention_days must be between 30 and 730."
  }
}

variable "maintenance_window" {
  description = "Weekly window used for both Kubernetes patch upgrades and node OS image upgrades."
  type = object({
    day_of_week    = optional(string, "Sunday")
    start_time     = optional(string, "02:00")
    duration_hours = optional(number, 4)
    utc_offset     = optional(string, "+00:00")
  })
  default = {}

  validation {
    condition     = contains(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], var.maintenance_window.day_of_week)
    error_message = "The maintenance_window.day_of_week must be a day name such as Sunday."
  }

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window.start_time))
    error_message = "The maintenance_window.start_time must be HH:MM in 24-hour time."
  }

  validation {
    condition     = var.maintenance_window.duration_hours >= 4 && var.maintenance_window.duration_hours <= 24
    error_message = "The maintenance_window.duration_hours must be between 4 and 24 (the AKS minimum is 4)."
  }

  validation {
    condition     = can(regex("^[+-](0[0-9]|1[0-4]):[0-5][0-9]$", var.maintenance_window.utc_offset))
    error_message = "The maintenance_window.utc_offset must look like +00:00 or -05:00."
  }
}

variable "tags" {
  description = "Tags added to every resource, merged over the module defaults."
  type        = map(string)
  default     = {}
}
