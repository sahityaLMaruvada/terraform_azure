provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version         = "=1.21.0"
  client_id       = "<client_id>"
  client_secret   = "<client_secret>"
  tenant_id       = "<tenant_id>"
  subscription_id = "<subscription_id>"
}

variable "environment" {
  default = "test"
}

resource "azurerm_resource_group" "test_env" {
  name     = "${var.environment}-resource-group"
  location = "East US"
}

resource "azurerm_network_security_group" "test_nsg" {
  name                = "${var.environment}-nsg"
  location            = "${azurerm_resource_group.test_env.location}"
  resource_group_name = "${azurerm_resource_group.test_env.name}"
}

resource "azurerm_network_security_rule" "test_nsg_rule_inbound" {
  name                        = "test-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.test_env.name}"
  network_security_group_name = "${azurerm_network_security_group.test_nsg.name}"
}

resource "azurerm_virtual_network" "test-network" {
  name                = "${var.environment}-network"
  address_space       = ["10.0.0.0/22"]
  location            = "${azurerm_resource_group.test_env.location}"
  resource_group_name = "${azurerm_resource_group.test_env.name}"
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = "${azurerm_resource_group.test_env.name}"
  virtual_network_name = "${azurerm_virtual_network.test-network.name}"
  address_prefix       = "10.0.0.0/24"
}

resource "azurerm_network_interface" "test-nic" {
  name                = "${var.environment}-nic"
  location            = "${azurerm_resource_group.test_env.location}"
  resource_group_name = "${azurerm_resource_group.test_env.name}"

  ip_configuration {
    name                          = "test-config"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.test-public-ip.id}"
  }
}

resource "azurerm_public_ip" "test-public-ip" {
  name                = "test-public-ip"
  location            = "${azurerm_resource_group.test_env.location}"
  resource_group_name = "${azurerm_resource_group.test_env.name}"

  #   public_ip_address_allocation = "static"
  allocation_method = "Static"
}

resource "azurerm_virtual_machine" "test-bigleaf-net" {
  name                  = "test.bigleaf.net"
  location              = "${azurerm_resource_group.test_env.location}"
  resource_group_name   = "${azurerm_resource_group.test_env.name}"
  network_interface_ids = ["${azurerm_network_interface.test-nic.id}"]
  vm_size               = "Standard_B4ms"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "credativ"
    offer     = "Debian"
    sku       = "8-backports"
    version   = "latest"
  }

  storage_os_disk {
    name              = "test-root"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "StandardSSD_LRS"
    disk_size_gb    = 10
  }

  os_profile {
    computer_name  = "test.bigleaf.net"
    admin_username = "testuser"
    admin_password = "%%53H@#mP3cP7Rj@"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags {
    environment = "test"
  }
}

resource "azurerm_managed_disk" "test-disk" {
  name                 = "test-disk"
  location             = "East US"
  resource_group_name  = "${azurerm_resource_group.test_env.name}"
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 100

  tags {
    environment = "test"
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "test-disk-attachment" {
  managed_disk_id    = "${azurerm_managed_disk.test-disk.id}"
  virtual_machine_id = "${azurerm_virtual_machine.test-bigleaf-net.id}"
  lun                = "2"
  caching            = "ReadWrite"
}
