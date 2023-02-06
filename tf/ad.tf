#if existing AD is used then get the domain join password as a data element

data "azurerm_key_vault" "domain_join_password" {
  count               = local.use_existing_ad ? 1 : 0
  name                = try(local.configuration_yml["ad"].existing_ad_details.domain_join_user.password_key_vault_name, "error")
  resource_group_name = try(local.configuration_yml["ad"].existing_ad_details.domain_join_user.password_key_vault_resource_group_name, "error")
}

data "azurerm_key_vault_secret" "domain_join_password" {
  count        = local.use_existing_ad ? 1 : 0
  name         = try(local.configuration_yml["ad"].existing_ad_details.domain_join_user.password_key_vault_secret_name, "error")
  key_vault_id = data.azurerm_key_vault.domain_join_password[0].id
}

resource "azurerm_network_interface" "ad-nic" {
  count               = local.use_existing_ad ? 0 : 1
  name                = "ad-nic"
  resource_group_name = local.create_rg ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.rg[0].name
  location            = local.create_rg ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.rg[0].location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = local.create_ad_subnet ? azurerm_subnet.ad[0].id : data.azurerm_subnet.ad[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "ad" {
  count               = local.use_existing_ad ? 0 : 1
  name                = "ad"
  resource_group_name = local.create_rg ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.rg[0].name
  location            = local.create_rg ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.rg[0].location
  size                = try(local.configuration_yml["ad"].vm_size, "Standard_D2s_v3")
  admin_username      = local.domain_join_user
  admin_password      = local.domain_join_password
  license_type        = try(local.configuration_yml["ad"].hybrid_benefit, false) ? "Windows_Server" : "None"

  network_interface_ids = [
    azurerm_network_interface.ad-nic[0].id,
  ]

  winrm_listener {
    protocol = "Http"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  dynamic "source_image_reference" {
    for_each = local.use_windows_image_id ? [] : [1]
    content {
      publisher = local.windows_base_image_reference.publisher
      offer     = local.windows_base_image_reference.offer
      sku       = local.windows_base_image_reference.sku
      version   = local.windows_base_image_reference.version
    }
  }

  source_image_id = local.windows_image_id

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_network_interface_application_security_group_association" "ad-asg-asso" {
  for_each                      = local.use_existing_ad ? [] : toset(local.asg_associations["ad"])
  network_interface_id          = azurerm_network_interface.ad-nic[0].id
  application_security_group_id = local.create_nsg ? azurerm_application_security_group.asg[each.key].id : data.azurerm_application_security_group.asg[each.key].id
}


## Second AD VM for high availability scenario
resource "azurerm_network_interface" "ad2-nic" {
  count               = local.ad_ha ? 1 : 0
  name                = "ad2-nic"
  resource_group_name = local.create_rg ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.rg[0].name
  location            = local.create_rg ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.rg[0].location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = local.create_ad_subnet ? azurerm_subnet.ad[0].id : data.azurerm_subnet.ad[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "ad2" {
  count               = local.ad_ha ? 1 : 0
  name                = "ad2"
  resource_group_name = local.create_rg ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.rg[0].name
  location            = local.create_rg ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.rg[0].location
  size                = try(local.configuration_yml["ad"].vm_size, "Standard_D2s_v3")
  admin_username      = local.domain_join_user
  admin_password      = local.domain_join_password
  license_type        = try(local.configuration_yml["ad"].hybrid_benefit, false) ? "Windows_Server" : "None"

  network_interface_ids = [
    azurerm_network_interface.ad2-nic[0].id,
  ]

  winrm_listener {
    protocol = "Http"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  dynamic "source_image_reference" {
    for_each = local.use_windows_image_id ? [] : [1]
    content {
      publisher = local.windows_base_image_reference.publisher
      offer     = local.windows_base_image_reference.offer
      sku       = local.windows_base_image_reference.sku
      version   = local.windows_base_image_reference.version
    }
  }

  source_image_id = local.windows_image_id

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_network_interface_application_security_group_association" "ad2-asg-asso" {
  for_each                      = local.ad_ha ? toset(local.asg_associations["ad"]) : []
  network_interface_id          = azurerm_network_interface.ad2-nic[0].id
  application_security_group_id = local.create_nsg ? azurerm_application_security_group.asg[each.key].id : data.azurerm_application_security_group.asg[each.key].id
}
