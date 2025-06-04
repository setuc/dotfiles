variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "key_vault_id" { type = string }
variable "storage_account_id" { type = string }
variable "app_insights_id" { type = string }
variable "tags" { type = map(string) default = {} }
