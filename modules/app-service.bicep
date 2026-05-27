@description('Azure region.')
param location string

@description('App Service Plan name.')
param appServicePlanName string

@description('Web App name (must be globally unique).')
param appServiceName string

@description('Linux runtime stack for the web app, e.g. NODE|20-lts.')
param linuxFxVersion string = 'NODE|20-lts'

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource site 'Microsoft.Web/sites@2024-04-01' = {
  name: appServiceName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      alwaysOn: true
      ipSecurityRestrictionsDefaultAction: 'Deny'
      scmIpSecurityRestrictionsDefaultAction: 'Deny'
    }
  }
}

output appServiceId string = site.id
output appServiceName string = site.name
output appServiceHostname string = site.properties.defaultHostName
