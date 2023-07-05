provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "example" {
  name     = "TestRGPkeerthanPOC"
  location = "West US"
}

# Create a virtual network
resource "azurerm_virtual_network" "example" {
  name                = "example-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  
}

# Create a subnet
resource "azurerm_subnet" "example" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.0.0/24"]
 }

# Create a gateway subnet
resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a public IP address
resource "azurerm_public_ip" "example" {
  name                = "example-public-ip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Dynamic"
  
}

# Create a VPN gateway
resource "azurerm_virtual_network_gateway" "example" {
  name                = "example-vpn-gateway"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  active_active       = false

    ip_configuration {
        name      = "example-gateway-ip-config"
        subnet_id = azurerm_subnet.gateway_subnet.id
        public_ip_address_id = azurerm_public_ip.example.id

    }

}

# Define the required routes
resource "azurerm_route_table" "example" {
  name                = "example-route-table"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  route {
    name                   = "example-route"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualNetworkGateway"
  }
  
}

# Create a load balancer
resource "azurerm_lb" "example" {
  name                = "example-lb"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  frontend_ip_configuration {
    name                 = "example-frontend-ip"
    subnet_id            = azurerm_subnet.example.id
  }
}

# Create a load balancer backend pool
resource "azurerm_lb_backend_address_pool" "example" {
  name                = "example-backend-pool"
  loadbalancer_id     = azurerm_lb.example.id
  #resource_group_name = azurerm_resource_group.example.name
}

# Create a load balancer rule
resource "azurerm_lb_rule" "example" {
  name                = "example-lb-rule"
  #resource_group_name = azurerm_resource_group.example.name
  loadbalancer_id     = azurerm_lb.example.id
  protocol            = "Tcp"
  frontend_port       = 80
  backend_port        = 80
  frontend_ip_configuration_name = "example-frontend-ip"
}

# Create a VMSS
resource "azurerm_linux_virtual_machine_scale_set" "example" {
  name                = "example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard_F2"
  admin_username      = "adminuser"
  instances           = 1
  disable_password_authentication = false
  admin_password    =  "Newuser@123"

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  network_interface {
    name = "example"
    primary = true

    ip_configuration {
      name = "internal"
      subnet_id = azurerm_subnet.example.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.example.id]
      #load_balancer_inbound_nat_rules_ids = [azurerm_lb.example_nat_rule.example.id]

    }
  }
  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

}

# Open TCP port 80 on the security group
resource "azurerm_network_security_group" "example" {
  name                = "example-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "AllowIncomingWebTraffic"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}