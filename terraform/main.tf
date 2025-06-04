terraform {
  required_version = ">= 1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "app_insights" {
  source              = "./modules/app_insights"
  name                = "${var.prefix}ai"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tags                = var.tags
}

module "storage_account" {
  source              = "./modules/storage_account"
  name                = "${var.prefix}storage"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tags                = var.tags
}

module "key_vault" {
  source              = "./modules/key_vault"
  name                = "${var.prefix}kv"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tags                = var.tags
}

module "ml_workspace" {
  source              = "./modules/ml_workspace"
  name                = "${var.prefix}aml"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  key_vault_id        = module.key_vault.name
  storage_account_id  = module.storage_account.name
  app_insights_id     = module.app_insights.id
  tags                = var.tags
}
