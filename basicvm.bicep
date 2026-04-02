// params general
param location string = 'germanywestcentral'
// params & vars for Servers

@description('The name of the Administrator of the new VM and Domain')
param adminUsername string 
@description('The password for the Administrator account of the new VM and Domain')
@secure()
param adminPassword string 

param vmSize string = 'Standard_D4s_v5'
param imagePublisher string = 'MicrosoftWindowsDesktop'
param imageOffer string = 'Windows-11'
@allowed([
  'win11-22h2-pro'
  'win11-23h2-pro'
])
param imageSKU string = 'win11-23h2-pro'
param numberOfInstances int = 1
param networkInterfaceName string = 'nic'
param osdiskname_prd string = 'prd_osdisk' 
param datadiskname_prd string = 'vmprd_datadisk'

//general nsg rules = allowing ping
var nsgrules = {
  securityrules:[
    {
      name: 'IN_Ping_ALLOW'
      properties: {
        access: 'Allow'
        description: 'Allow PING from VNET'
        destinationAddressPrefix: 'VirtualNetwork'
        destinationPortRange: '*'
        direction:'inbound'
        priority: 300
        protocol: 'Icmp'
        sourceAddressPrefix: 'VirtualNetwork'
        sourcePortRange: '*'
      } 
    }
  ]
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'networkSecurityGroup'
  location: location
  properties: {
    securityRules: nsgrules.securityrules
  }
}

// NAT Gateway public IP
resource natGatewayPublicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'natGatewayPublicIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// NAT Gateway
resource natGateway 'Microsoft.Network/natGateways@2023-05-01' = {
  name: 'natGateway'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: natGatewayPublicIP.id
      }
    ]
    idleTimeoutInMinutes: 4
  }
}

// VPN Gateway public IP
resource vpnGatewayPublicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'vpnGatewayPublicIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

//hubnet including subnets
resource VnetName 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'Vnet03'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.3.0.0/16'
      ]
    }
    subnets: []
    enableDdosProtection: false
    enableVmProtection: true
  }
}

resource serversubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: 'serversubnet'
  parent: VnetName
  dependsOn: [
    VnetName
    natGateway
  ]
  properties: {
    addressPrefix: '10.3.0.0/24'
    networkSecurityGroup: {
      id: nsg.id
    }
    natGateway: {
      id: natGateway.id
    }
  }
}

// GatewaySubnet required by VPN Gateway (no NSG or NAT gateway allowed)
resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: 'GatewaySubnet'
  parent: VnetName
  dependsOn: [
    serversubnet
  ]
  properties: {
    addressPrefix: '10.3.1.0/27'
  }
}

// VPN Gateway
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-05-01' = {
  name: 'vpnGateway'
  location: location
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    ipConfigurations: [
      {
        name: 'vpnGatewayIpConfig'
        properties: {
          publicIPAddress: {
            id: vpnGatewayPublicIP.id
          }
          subnet: {
            id: gatewaySubnet.id
          }
        }
      }
    ]
  }
  dependsOn: [
    gatewaySubnet
  ]
}

//client vm
// create the nic
resource nicNameprd 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, numberOfInstances):{
  name: 'prod-client-${networkInterfaceName}${i}'
  location: location
  dependsOn: [
    VnetName
    serversubnet
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: serversubnet.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: false
    enableIPForwarding: true
  }
}]

// Create the Windows 11 client VM
resource serverprd 'Microsoft.Compute/virtualMachines@2020-12-01' = [for i in range(0, numberOfInstances):{
  name: 'client${i}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'win11client-${i}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSKU
        version: 'latest'
      }
      osDisk: {
        name:'${osdiskname_prd}${i}'
        caching: 'None'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          name:'${datadiskname_prd}${i}'
          diskSizeGB: 128
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicNameprd[i].id
        }
      ]
    }
  }
  dependsOn: [
    nicNameprd
  ]
}]
