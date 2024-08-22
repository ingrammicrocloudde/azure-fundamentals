// params general
param location string = 'northeurope'
// params & vars for Servers

@description('The name of the Administrator of the new VM and Domain')
param adminUsername string 
@description('The password for the Administrator account of the new VM and Domain')
@secure()
param adminPassword string 

param vmSize string =  'Standard_D2s_v5'
param imagePublisher string = 'MicrosoftWindowsServer'
param imageOffer string = 'WindowsServer'
@allowed([
  '2019-Datacenter'
  '2022-Datacenter'
])
param imageSKU string =  '2022-Datacenter'
param numberOfInstances int =1
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


//hubnet including subnet
resource VnetName 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'Vnet03'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.3.0.0/16'
      ]
    }
    subnets: [
    
    ]
    enableDdosProtection: false
    enableVmProtection: true
    }
}
resource serversubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: 'serversubnet'
  parent: VnetName 
  dependsOn: [
    VnetName
  ]
    properties: {
      addressPrefix: '10.3.0.0/24'
      networkSecurityGroup: {
        id: nsg.id
      }
    }
 
}
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'networkSecurityGroup'
  location: location
  properties: {
    securityRules: nsgrules.securityrules
  }
  dependsOn: [

  ]
}

//servers
//prdserver
// create the prd nic
resource nicNameprd 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, numberOfInstances):{
  name: 'prod-server-${networkInterfaceName}${i}'
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
  
 }
]

// Create the prd vm
resource serverprd 'Microsoft.Compute/virtualMachines@2020-12-01' = [for i in range(0, numberOfInstances):{
  name: 'serverprd${i}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'prdsrv-${i}'
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
 }
]


