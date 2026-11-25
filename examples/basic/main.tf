terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.14"
    }
  }
}

# The subscription comes from ARM_SUBSCRIPTION_ID (or `az account show` when using Azure CLI auth).
provider "azurerm" {
  features {}
}

module "aks" {
  source = "../../modules/aks"

  name                   = var.name
  location               = var.location
  resource_group_name    = var.resource_group_name
  network_plugin         = var.network_plugin
  system_node_pool       = var.system_node_pool
  user_node_pool         = var.user_node_pool
  azure_rbac_enabled     = var.azure_rbac_enabled
  admin_group_object_ids = var.admin_group_object_ids
  tags                   = var.tags
}
