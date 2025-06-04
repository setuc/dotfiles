resource "azurerm_machine_learning_workspace" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  key_vault_id        = var.key_vault_id
  storage_account_id  = var.storage_account_id
  application_insights_id = var.app_insights_id
  tags                   = var.tags
}
