data "azurerm_resource_group" "myterraformgroup" {
  name = "${var.rgName}"
}

data "azurerm_virtual_network" "myterraformnetwork" {
  name                = "${var.network}"
  resource_group_name = "${data.azurerm_resource_group.myterraformgroup.name}"
}

data "azurerm_subnet" "myterraformsubnet" {
  name                 = "${var.subnet}"
  virtual_network_name = "${data.azurerm_virtual_network.myterraformnetwork.name}"
  resource_group_name  = "${data.azurerm_resource_group.myterraformgroup.name}"
 # address_prefix       = "10.4.0.0/24"
}
resource "random_pet" "rebuild_again_please" {}
resource "azurerm_network_interface" "myterraformnic" {
    count = "${var.instcount}"
    name                = "${var.vmname}-nic-${count.index}"
    location            = "${var.region}"
    resource_group_name = "${data.azurerm_resource_group.myterraformgroup.name}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${data.azurerm_subnet.myterraformsubnet.id}"
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "${var.environment}"
        owner = "${var.owner}"
        costcenter = "${var.costcenter}"
        
    }
}

resource "random_id" "randomId" {
  # keepers = {
     #   Generate a new ID only when a new resource group is defined
    #   resource_group = "${data.azurerm_resource_group.myterraformgroup.name}"
   # }
    
    byte_length = 8
}

resource "azurerm_storage_account" "mystorageaccount" {
    name                = "diag${random_id.randomId.hex}"
    resource_group_name = "${data.azurerm_resource_group.myterraformgroup.name}"
    location            = "${var.region}"
    account_replication_type = "LRS"
    account_tier = "Standard"

    tags = {
        environment = "Terraform Demo"
    }
}


resource "azurerm_virtual_machine" "myterraformvm" {
    count = "${var.instcount}"
    name                  = "${var.vmname}-${count.index}"
    location              = "${var.region}"
    resource_group_name   = "${data.azurerm_resource_group.myterraformgroup.name}"
    network_interface_ids = ["${element(azurerm_network_interface.myterraformnic.*.id, count.index)}"]
    vm_size               = "${var.hardwaretype}"
    delete_os_disk_on_termination = true

    storage_os_disk {
        name              = "myOsDisk-${count.index}${random_id.randomId.hex}"
        caching           = "ReadWrite"
       # managed_disk_id = "${azurerm_managed_disk.mymanagedtfdisk.*.id[count.index]}"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "myvm"
        admin_username = "${var.username}"
       # admin_password = "Cmpdev@123"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.username}/.ssh/authorized_keys"
            key_data = "${var.sshkey}"
        }
    }

    boot_diagnostics {
        enabled     = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

     tags = {
        environment = "${var.environment}"
        owner = "${var.owner}"
        costcenter = "${var.costcenter}"
        
    }
}

