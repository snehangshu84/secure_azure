# ==============================================================================
# MODULE: Network Foundation (Hub VNet & Security Controls)
# DESCRIPTION: Deploys the secure Hub VNet and foundational NSGs, enforcing
#              a deny-by-default posture for all network traffic, suitable for
#              a highly regulated finance environment.
# ==============================================================================

# --- VARIABLES INPUT (Assumed to be defined in infra/modules/network/variables.tf) ---
# module.var.resource_group_name: The RG where the resources will reside.
# module.var.location: Azure Region (e.g., "eastus").
# module.var.vnet_cidr: The CIDR block for the entire Hub VNet (e.g., "10.0.0.0/16").
# module.var.public_ip_cidr: CIDR for any required public components (if applicable).

# ------------------------------------------------------------------------------
# 1. RESOURCE GROUP (For explicit management of the network stack)
# NOTE: It is better practice to manage this externally, but included for completeness.
# ----------------------------------------------------------------------------------
# main.tf

# 1. Resource Group Definition
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# 2. Virtual Network Definition
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.cidr_block
}

# 3. Subnet Definitions (The partition blocks)
# Subnet 1: For application compute resources
resource "azurerm_subnet" "app_subnet" {
  name                 = "AppSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = "10.0.1.0/24"
}

# Subnet 2: For network infrastructure (e.g., jumpboxes, gateways)
resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = "10.0.2.0/24"
}

# 4. Network Security Group (NSG) Definition (The Firewall)
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.rg.name
  resource_group_name = azurerm_resource_group.rg.name
}

# 5. NSG Security Rules (Enforcing Least Privilege)

# A. INGRESS Rule: Allow HTTPS from the internet (A practical example)
# IMPORTANT: In a real scenario, restrict the source IP range!
resource "azurerm_network_security_rule" "allow_https_ingress" {
  name                = "Allow_HTTPS_Inbound"
  priority            = 100
  direction           = "Inbound"
  source_port_range   = "*"
  destination_port_range = "443"
  source_address_prefix = "*" # WARNING: Change this to a specific CIDR range!
  destination_address_prefix = "*"
  resource_group_name = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# B. INGRESS Rule: Deny all other inbound traffic (Safety net)
resource "azurerm_network_security_rule" "deny_all_ingress" {
  name                = "Deny_All_Ingress"
  priority            = 4090 # Low priority ensures it only catches what was missed
  direction           = "Inbound"
  action              = "Deny"
  priority            = 4090
  source_port_range   = "*"
  destination_port_range = "*"
  source_address_prefix = "*"
  destination_address_prefix = "*"
  resource_group_name = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# C. EGRESS Rule: Allow all outbound traffic (Necessary for internet access)
# This rule is often best left out unless you need to restrict outbound traffic.
# We add it here for completeness.
resource "azurerm_network_security_rule" "allow_egress" {
  name                = "Allow_All_Egress"
  priority            = 100
  direction           = "Outbound"
  action              = "Allow"
  priority            = 100
  source_port_range   = "*"
  destination_port_range = "*"
  source_address_prefix = "*"
  destination_address_prefix = "*"
  resource_group_name = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}


# 6. NSG Association (Attaching the Firewall to the Subnets)
# This applies the rules defined in 'azurerm_network_security_group.nsg' to the subnets.
resource "azurerm_subnet_network_security_group_association" "app_assoc" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "gateway_assoc" {
  subnet_id                 = azurerm_subnet.gateway_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

/*
=================================================================================
NOTES ON VARIABLES AND DEPLOYMENT:
1. This HCL template assumes that variables (e.g., location, resource_group_name,
   trusted_office_cidr) are defined in a 'variables.tf' file or provided via CLI.
2. The CIDR blocks used (10.0.1.0/24, 10.0.10.0/24, 10.0.100.0/24) must not overlap
   with any existing networks.
=================================================================================
*/