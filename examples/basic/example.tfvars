name                = "akslab"
location            = "westeurope"
resource_group_name = "rg-akslab"
network_plugin      = "azure"

system_node_pool = {
  vm_size    = "Standard_B2s"
  node_count = 1
}

user_node_pool = {
  enabled   = true
  vm_size   = "Standard_B2s"
  min_count = 0
  max_count = 2
}

azure_rbac_enabled = false

tags = {
  owner = "you"
}
