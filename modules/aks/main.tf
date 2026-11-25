locals {
  tags = merge({ managed-by = "terraform", purpose = "lab" }, var.tags)

  # Referencing the resource (not just the variable) makes everything wait for the group to exist.
  resource_group_name = var.create_resource_group ? azurerm_resource_group.this[0].name : var.resource_group_name

  maintenance_window = {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = var.maintenance_window.day_of_week
    start_time  = var.maintenance_window.start_time
    duration    = var.maintenance_window.duration_hours
    utc_offset  = var.maintenance_window.utc_offset
  }
}

resource "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 1 : 0

  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  address_space       = [var.vnet_address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "nodes" {
  name                 = "snet-${var.name}-nodes"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix]
}

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

# A user-assigned identity exists before the cluster, so it can be granted rights on the
# VNet up front (load balancers in the subnet, and the route table kubenet attaches).
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${var.name}-control-plane"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = local.tags
}

resource "azurerm_role_assignment" "control_plane_network" {
  scope                = azurerm_virtual_network.this.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}

# Container Insights with managed-identity auth needs a data collection rule associated
# with the cluster; the portal and CLI create it implicitly, Terraform has to do it explicitly.
resource "azurerm_monitor_data_collection_rule" "container_insights" {
  name                = "MSCI-${var.location}-${var.name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = local.tags

  destinations {
    log_analytics {
      name                  = "ciworkspace"
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerInsights-Group-Default"]
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = ["Microsoft-ContainerInsights-Group-Default"]
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Off"
          enableContainerLogV2   = true
        }
      })
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "container_insights" {
  name                    = "ContainerInsightsExtension"
  target_resource_id      = azurerm_kubernetes_cluster.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.container_insights.id
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"
  tags                = local.tags

  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  role_based_access_control_enabled = true

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_pool.vm_size
    node_count                   = var.system_node_pool.node_count
    os_disk_size_gb              = var.system_node_pool.os_disk_size_gb
    vnet_subnet_id               = azurerm_subnet.nodes.id
    only_critical_addons_enabled = var.user_node_pool.enabled
    temporary_name_for_rotation  = "systemtmp"
    tags                         = local.tags

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  network_profile {
    network_plugin    = var.network_plugin
    load_balancer_sku = "standard"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
    pod_cidr          = var.network_plugin == "kubenet" ? var.pod_cidr : null
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.this.id
    msi_auth_for_monitoring_enabled = true
  }

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.azure_rbac_enabled ? [1] : []
    content {
      azure_rbac_enabled     = true
      admin_group_object_ids = var.admin_group_object_ids
    }
  }

  maintenance_window_auto_upgrade {
    frequency   = local.maintenance_window.frequency
    interval    = local.maintenance_window.interval
    day_of_week = local.maintenance_window.day_of_week
    start_time  = local.maintenance_window.start_time
    duration    = local.maintenance_window.duration
    utc_offset  = local.maintenance_window.utc_offset
  }

  maintenance_window_node_os {
    frequency   = local.maintenance_window.frequency
    interval    = local.maintenance_window.interval
    day_of_week = local.maintenance_window.day_of_week
    start_time  = local.maintenance_window.start_time
    duration    = local.maintenance_window.duration
    utc_offset  = local.maintenance_window.utc_offset
  }

  depends_on = [azurerm_role_assignment.control_plane_network]
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count = var.user_node_pool.enabled ? 1 : 0

  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  mode                  = "User"
  vm_size               = var.user_node_pool.vm_size
  os_disk_size_gb       = var.user_node_pool.os_disk_size_gb
  vnet_subnet_id        = azurerm_subnet.nodes.id
  auto_scaling_enabled  = true
  min_count             = var.user_node_pool.min_count
  max_count             = var.user_node_pool.max_count
  tags                  = local.tags

  upgrade_settings {
    max_surge = "10%"
  }
}
