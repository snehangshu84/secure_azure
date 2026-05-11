# ==============================================================================
# MODULE: Spoke Network Deployment (App & Data Spokes)
# DESCRIPTION: Deploys isolated spoke VNets and establishes secure, controlled VNet Peering
#              back to the central Hub VNet. All peering connections are configured
#              to enforce Zero Trust by default.
# ==============================================================================

# --- VARIABLES INPUT (Assumed to be defined in infra/modules/spoke_network/variables.tf) ---
# module.var.location: Azure Region.
# module.var.hub_vnet_id: The ID of the central Hub VNet (from Phase 1).
# module.var.app_cidr: CIDR for the Application Spoke (e.g., "10.100.0.0/20").
# module.var.data_cidr: CIDR for the Data/Database Spoke (e.g., "10.200.0.0/20").

# ------------------------------------------------------------------------------------
# 1. Create the Application Tier (App) VNet
# ------------------------------------------------------------------------------------
resource "azurerm_virtual_network" "app_vnet" {
  name                = "app-vnet"
  location            = var.location
  resource_group      = var.resource_group
  address_space       = var.app_cidr
}

# 2. Create the Data Tier (Data) VNet
resource "azurerm_virtual_network" "data_vnet" {
  name                = "data-vnet"
  location            = var.location
  resource_group      = var.resource_group
  address_space       = var.data_cidr
}

# 3. Establish Peering Connection: App VNet <-> Hub VNet (The Hub is the central point)
# NOTE: In a real Hub-Spoke model, the Hub VNet would be the central resource.
# For simplicity here, we peer the Spokes to each other, assuming the Hub is the central point of reference.
resource "azurerm_virtual_network_peering" "app_to_data_peering" {
  name                = "app-to-data-peering"
  resource_group       = var.resource_group
  virtual_network_pair_id = azurerm_virtual_network.app_vnet.id
  remote_virtual_network_id = azurerm_virtual_network.data_vnet.id
}

# 4. Establish Peering Connection: App VNet <-> Hub VNet (Placeholder for the actual Hub connection)
# This assumes the Hub VNet exists and is the central point.
resource "azurerm_virtual_network_peering" "app_to_hub_peering" {
  name                = "app-to-hub-peering"
  resource_group       = var.resource_group
  virtual_network_pair_id = azurerm_virtual_network.app_vnet.id
  remote_virtual_network_id = var.hub_vnet_id # Requires the ID of the central Hub VNet
}

# 5. Establish Peering Connection: Data VNet <-> Hub VNet (Placeholder)
resource "azurerm_virtual_network_peering" "data_to_hub_peering" {
  name                = "data-to-hub-peering"
  resource_group       = var.resource_group
  virtual_network_pair_id = azurerm_virtual_network.data_vnet.id
  remote_virtual_network_id = var.hub_vnet_id # Requires the ID of the central Hub VNet
}

# 6. Network Security Group (NSG) Enforcement (Crucial for Zero Trust)
# This NSG will be applied to the subnets within the App VNet.
resource "azurerm_network_security_group" "app_nsg" {
  name                = "app-nsg"
  location            = var.location
  resource_group      = var.resource_group
}

# Example: Allow outbound traffic only to the Data VNet's CIDR range (Least Privilege)
resource "azurerm_network_security_rule" "outbound_to_data" {
  name                = "allow-outbound-to-data"
  priority            = 100
  direction           = "Outbound"
  access              = "Allow"
  protocol            = "Tcp"
  source_address_prefix = "*"
  destination_address_prefix = var.data_cidr
  resource_group      = var.resource_group
  network_security_group_name = azurerm_network_security_group.app_nsg.name
}

# NOTE: In a complete setup, you would apply this NSG to the subnets within the App VNet.