@description('Front Door profile name (must exist).')
param frontDoorProfileName string

@description('App Service name (must exist).')
param appServiceName string

@description('Log Analytics workspace resource ID.')
param workspaceId string

resource frontDoor 'Microsoft.Cdn/profiles@2024-02-01' existing = {
  name: frontDoorProfileName
}

resource appService 'Microsoft.Web/sites@2024-04-01' existing = {
  name: appServiceName
}

resource frontDoorDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'frontdoor-to-log-analytics'
  scope: frontDoor
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'FrontDoorAccessLog'
        enabled: true
      }
      {
        category: 'FrontDoorHealthProbeLog'
        enabled: true
      }
      {
        category: 'FrontDoorWebApplicationFirewallLog'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource appServiceDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'appservice-to-log-analytics'
  scope: appService
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
