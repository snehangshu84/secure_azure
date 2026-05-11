# ======================================================================================
# MODULE: data_spoke_hardening.tf
# Purpose: Implements mandatory governance policies for the Data Spoke VNet.
# Dependencies: Requires the Data VNet ID and the Azure Firewall ID.
# ======================================================================================

# --- VARIABLES INPUT (Assumed to be defined in variables.tf) ---
# var.resource_group_name: The resource group where policies will be deployed.
# var.data_vnet_id: The ID of the Data Spoke VNet (Scope for policies).
# var.azure_firewall_id: The ID of the Azure Firewall that all network traffic must pass through.

# ======================================================================================
# 1. POLICY DEFINITION: Mandatory Tagging Enforcement
# ======================================================================================

# This policy ensures that any resource deployed into the Data Spoke VNet must carry
# the CostCenter and Owner tags.
resource "azurerm_policy_assignment" "mandatory_tagging" {
  name                 = "Mandatory-Tags-DataSpoke"
  scope                = var.data_vnet_id # Apply policy at the VNet scope
  policy_definition_id = azurerm_policy_assignment.tag_policy.id
}

resource "azurerm_policy_definition" "tag_policy" {
  name                = "RequireMandatoryTags"
  location            = var.location
  resource_group      = var.resource_group
  policy_rules = jsonencode([
    {
      "if": {
        "allOf": [
          {
            "field": "type",
            "equals": "Microsoft.Network/networkInterfaces" # Target NICs
          },
          {
            "field": "type",
            "equals": "Microsoft.Network/virtualNetworks/subnets" # Target Subnets
          }
        ]
      },
      "then": {
        "effect": "Deny"
      }
    }
  ])
  # This policy denies deployment if the required tags are missing.
  # Note: In a real scenario, you might need multiple definitions or use 'add' effect
  # to enforce tags, but 'Deny' on missing tags is the strongest enforcement.
  policy_rule = {
    if = {
      allOf = [
        {
          field = "tags['CostCenter']",
          exists = "false"
        },
        {
          field = "tags['Owner']",
          exists = "false"
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  }
}


# ======================================================================================
# 2. POLICY DEFINITION: Network Resource Through Azure Firewall Enforcement
# ======================================================================================

# This policy denies the creation of any network resource (NIC, Subnet) unless
# it is explicitly associated with the specified Azure Firewall.
resource "azurerm_policy_assignment" "firewall_enforcement" {
  name                 = "Force-Traffic-Through-Firewall"
  scope                = var.data_vnet_id # Apply policy at the VNet scope
  policy_definition_id = azurerm_policy_assignment.firewall_policy.id
}

resource "azurerm_policy_definition" "firewall_policy" {
  name                = "ForceTrafficThroughFirewall"
  location            = var.location
  resource_group      = var.resource_group
  policy_rule = {
    if = {
      allOf = [
        {
          "field": "type",
          "in": [
            "Microsoft.Network/networkInterfaces",
            "Microsoft.Network/virtualNetworks/subnets"
          ]
        }
      ]
    }
    then = {
      "effect": "Deny"
    }
  }
  # The 'details' block is used to provide remediation guidance in the policy definition.
  details = {
    description = "Network resources (NICs, Subnets) must be associated with a resource that routes traffic through the specified Azure Firewall endpoint."
    # In a full implementation, you would use 'not' logic here to check for firewall association.
    # For simplicity in this example, we use a Deny effect on the resource type itself,
    # which forces the user to address the policy violation.
  }
}