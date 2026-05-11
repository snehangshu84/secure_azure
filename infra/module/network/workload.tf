# =============================================================
# 1. APPLICATION WORKLOAD (App Service in App Spc)
# Goal: Deploy the containerized application into the App Service Plan
# =============================================================

# App Service Plan (The container for your App Service)
resource "azurerm_service_plan" "app_service_plan" {
  name     = "app-sp-plan"
  location = var.location
  resource_group_name = var.resource_group
  
  # Ensure the App Service Plan is connected to the VNet/Subnet
  vnet_subnet_id = var.app_subnet_id 
  sku_name = "Standard" # Use a SKU that supports VNet integration
}

# App Service (The actual deployed application)
resource "azurerm_app_service" "app_service" {
  name                = "secure-web-app"
  location            = var.location
  resource_group_name = var.resource_group
  service_plan_id     = azurerm_service_plan.app_service_plan.id
  
  # Enable VNet integration to restrict outbound traffic
  # This forces the App Service to use the private IPs within the subnet
  site_config {
    vnet_subnet_id = var.app_subnet_id
  }
}


# =============================================================
# 2. DATA WORKLOAD (Azure SQL Database)
# Goal: Securely deploy the database instance
# =============================================================

# Resource Group for the Database
resource "azurerm_resource_group" "db_rg" {
  name     = "db-rg"
  location = var.location
}

# Create the SQL Server instance
resource "azurerm_sql_server" "sql_server" {
  name                         = "secure-sql-server"
  resource_group_name          = azurerm_resource_group.db_rg.name
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_user_password = var.sql_admin_password
}

# Create the database within the SQL Server
resource "azurerm_sql_database" "sql_db" {
  name                = "secure-data-store"
  resource_group_name = azurerm_resource_group.db_rg.name
  location            = var.location
  account_name        = azurerm_sql_server.sql_server.name
}


# =============================================================
# 3. NETWORK SECURITY & ACCESS CONTROL (Crucial Step)
# Goal: 
# 1. Create a Private Endpoint for the SQL DB.
# 2. Allow outbound traffic only from the App Subnet to the Private Endpoint.
# =============================================================

# --- 3a. Network Setup for Secure Communication ---

# 1. Private Endpoint for the SQL Database
# This ensures the connection uses a private IP in the VNet, not the public internet.
resource "azurerm_private_endpoint" "sql_private_endpoint" {
  name                = "sql-private-ep"
  location            = var.location
  resource_group_name = azurerm_resource_group.db_rg.name
  subnet_id           = var.app_subnet_id # Connects to the App Subnet
  
  private_service_connection {
    name                           = "sql-connection"
    private_service_name          = azurerm_sql_server.sql_server.name
    private_ip_address_space      = "10.0.0.0/16" # Use your VNet's CIDR range
  }
}

# 2. Network Security Group (NSG) to enforce rules on the App Subnet
# This acts as the firewall for the application's subnet.
resource "azurerm_network_security_group" "app_nsg" {
  name                = "app-outbound-nsg"
  location            = var.location
  resource_group_name = var.resource_group
}

# 3. Inbound Rule: Allow App Service traffic to the Private Endpoint
# Allows traffic *from* the subnet *to* the private endpoint IP range.
resource "azurerm_network_security_rule" "allow_sql_access" {
  name                = "allow-sql-access"
  priority            = 100
  direction           = "Outbound" # Traffic originating from the App Service Subnet
  source_address_prefix = var.app_subnet_cidr # From the App Subnet
  destination_address_prefix = azurerm_private_endpoint.sql_private_endpoint.private_service_ip # To the private IP
  protocol            = "Tcp"
  source_port_range   = "*"
  destination_port_range = "1433" # Default SQL Port
  resource_group_name = var.resource_group
  network_security_group_name = azurerm_network_security_group.app_nsg.name
}

# 4. Associate the NSG with the App Subnet (The enforcement point)
resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  subnet_id = var.app_subnet_id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}


# =============================================================
# 4. SECURITY BEST PRACTICE: Update Connection Strings
# (In a real scenario, use Azure Key Vault for these secrets)
# =============================================================

# Output the connection string (DO NOT USE THIS IN PRODUCTION)
output "sql_connection_string" {
  description = "The connection string for the SQL Database"
  value       = "Server=tcp(${azurerm_sql_server.sql_server.fully_qualified_domain_name},1433;Database=${azurerm_sql_database.sql_db.name};User Id=${azurerm_sql_server.sql_server.administrator_login};Password=${var.sql_admin_password};"
}
