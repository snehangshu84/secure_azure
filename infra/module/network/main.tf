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
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# ----------------------------------------------------------------------------------
# 2. VIRTUAL NETWORK (The central backbone)
# ----------------------------------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# ----------------------------------------------------------------------------------
# 3. SUBNETS
#    Definition of segregated network segments.
# ----------------------------------------------------------------------------------

# A. Gateway Subnet (For VPN/ExpressRoute components - Placeholder)
resource "azurerm_subnet" "gw_subnet" {
  name                 = "GatewaySubnet"
  parent_network_association {
    parent_resource_id = azurerm_virtual_network.vnet.id
  }
  address_prefixes = ["10.0.1.0/24"]
}

# B. Subnet for Management & Bastion (Highly restricted access)
resource "azurerm_subnet" "mgmt_subnet" {
  name                 = "ManagementSubnet"
  parent_network_association {
    parent_resource_id = azurerm_virtual_network.vnet.id
  }
  address_prefixes = ["10.0.10.0/24"]
}

# C. Subnet for Application Services (Where primary workloads reside)
resource "azurerm_subnet" "app_subnet" {
  name                 = "AppSubnet"
  parent_network_association {
    parent_resource_id = azurerm_virtual_network.vnet.id
  }
  address_prefixes = ["10.0.100.0/24"]
}

# ----------------------------------------------------------------------------------
# 4. NETWORK SECURITY GROUPS (NSGs) - The primary firewall mechanism
# ----------------------------------------------------------------------------------

# A. NSG for Management Subnet: Whitelists only necessary ports (e.g., RDP/SSH from Bastion only)
resource "azurerm_network_security_group" "nsg_mgmt" {
  name                = "NSG-MGMT-RESTRICTED"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Allow SSH (22) ONLY from a specific trusted CIDR range (e.g., the corporate office IP).
resource "azurerm_network_security_rule" "ssh_ingress" {
  name                               = "Allow-SSH-Bastion"
  priority                           = 100
  direction                         = "Inbound"
  access                             = "Allow"
  protocol                           = "Tcp"
  source_port_range                 = "*"
  destination_port_range            = "22"
  source_address_prefix             = var.trusted_office_cidr
  destination_address_prefix       = "*"
  resource_group_name               = azurerm_resource_group.rg.name
  network_security_group_name       = azurerm_network_security_group.nsg_mgmt.name
}

# B. NSG for App Subnet: Allows inbound HTTP/HTTPS from the internet (If necessary)
resource "azurerm_network_security_group" "nsg_app" {
  name                = "NSG-APP-WEB"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Allow Inbound HTTP (80) and HTTPS (443) from the entire Internet (0.0.0.0/0).
resource "azurerm_network_security_rule" "http_ingress" {
  name                               = "Allow-HTTP-Internet"
  priority                           = 100
  direction                         = "Inbound"
  access                             = "Allow"
  protocol                           = "Tcp"
  source_port_range                 = "*"
  destination_port_range            = "80"
  source_address_prefix             = "0.0.0.0/0"
  destination_address_prefix       = "*"
  resource_group_name               = azurerm_resource_group.rg.name
  network_security_group_name       = azurerm_network_security_group.nsg_app.name
}

resource "azurerm_network_security_rule" "https_ingress" {
  name                               = "Allow-HTTPS-Internet"
  priority                           = 100
  direction                         = "Inbound"
  access                             = "Allow"
  protocol                           = "Tcp"
  source_port_range                 = "*"
  destination_port_range            = "443"
  source_address_prefix             = "0.0.0.0/0"
  destination_address_prefix       = "*"
  resource_group_name               = azurerm_resource_group.rg.name
  network_security_group_name       = azurerm_network_security_group.nsg_app.name
}

# ----------------------------------------------------------------------------------
# 5. ATTACHING NSGs to Subnets (Binding the firewall rules)
# ----------------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "mgmt_binding" {
  subnet_id = azurerm_subnet.mgmt_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg_mgmt.id
}

resource "azurerm_subnet_network_security_group_association" "app_binding" {
  subnet_id = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg_app.id
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