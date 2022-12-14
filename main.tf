locals {
  app_name = "${var.env}-${var.business_product_name}-${var.suffix}"
  tags = {
    "generated-by"     = "github-actions|terraform"
    "build-version"    = "1.0.0.0"
    "build-timestamp"  = timestamp()
    "owner"            = var.owner
    "costcenter"       = var.costcenter
    "monitoring"       = var.monitoring
    "env"              = var.env
    "business_product" = var.business_product_name
  }
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group_name
}

resource "azurerm_resource_group" "main" {
  name     = "${local.app_name}-rg"
  location = var.resource_location

  tags = local.tags
}

resource "azurerm_network_interface" "nic" {
  name                = "${local.app_name}-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "${local.app_name}-vm-nic-config"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    resource.azurerm_resource_group.main
  ]
}

resource "azurerm_virtual_machine" "vm" {
  name                             = "${local.app_name}-vm"
  location                         = azurerm_resource_group.main.location
  resource_group_name              = azurerm_resource_group.main.name
  network_interface_ids            = [azurerm_network_interface.nic.id]
  vm_size                          = var.vm_size
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = var.vm_publisher
    offer     = var.vm_offer
    sku       = var.vm_sku
    version   = var.vm_version
  }

  storage_os_disk {
    name              = "${local.app_name}-vm-disk-os"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    create_option     = "FromImage"
  }

  storage_data_disk {
    name              = "${local.app_name}-vm-disk-data"
    disk_size_gb      = var.vm_disk_data_size_gb
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    lun               = 0
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = var.vm_admin_username
    admin_password = var.vm_admin_password
  }

  os_profile_windows_config {
    enable_automatic_upgrades = true
  }

  tags = local.tags

  depends_on = [
    resource.azurerm_network_interface.nic
  ]
}