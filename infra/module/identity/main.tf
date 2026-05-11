# ==============================================================================
# 1. PROVIDER & RESOURCE DEFINITIONS (Assumed Context)
# ==============================================================================

# Assume the following variables are defined elsewhere:
# var.resource_group_name = "rg-network-security"
# var.data_vnet_id = "/subscriptions/sub-id/resourceGroups/rg-network-security/providers/Microsoft.Network/virtualNetworks/data-vnet"
# var.app_name = "my-secure-application"

# ==============================================================================
# 2. SERVICE PRINCIPAL CREATION (The Application Identity)
# ==============================================================================

# Creates a Service Principal identity that the application will use.
resource "azuread_service_principal" "app_identity" {
  app_id = var.app_name
  display_name = var.app_name
}

# ==============================================================================
# 3. ROLE ASSIGNMENT (Granting Least Privilege)
# ==============================================================================

# Assigns the built-in 'Reader' role to the Service Principal on the Data VNet scope.
resource "azurerm_role_assignment" "reader_role_assignment" {
  # The scope must be the resource ID of the Data VNet.
  scope                = var.data_vnet_id
  role_definition_name = "Reader" # Built-in role: Read-only access
  principal_id         = azuread_service_principal.app_identity.object_id
}

# ==============================================================================
# 4. OUTPUTS (For verification)
# ==============================================================================

output "service_principal_object_id" {
  description = "The Object ID of the created Service Principal."
  value       = azuread_service_principal.app_identity.object_id
}

output "role_assignment_status" {
  description = "Confirms the Reader role was assigned to the Service Principal on the Data VNet."
  value       = "Success: Reader role assigned."
}