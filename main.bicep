targetScope = 'resourceGroup'

@description('Azure region for regional resources (workspace, app plan, app service).')
param location string = resourceGroup().location

@description('Lowercase short prefix used to derive resource names (3-10 chars).')
@minLength(3)
@maxLength(10)
param namePrefix string = 'afdsec'

@description('Log Analytics retention in days.')
@minValue(30)
@maxValue(730)
param logRetentionDays int = 30

@description('Linux runtime stack for the App Service origin.')
param appRuntime string = 'NODE|20-lts'

var suffix = uniqueString(resourceGroup().id)
var workspaceName = '${namePrefix}-law-${suffix}'
var planName = '${namePrefix}-plan-${suffix}'
var appName = '${namePrefix}-app-${suffix}'
var wafName = '${namePrefix}waf${suffix}'
var frontDoorName = '${namePrefix}-afd-${suffix}'
var endpointName = '${namePrefix}-ep'

module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'logAnalyticsDeploy'
  params: {
    location: location
    workspaceName: workspaceName
    retentionInDays: logRetentionDays
  }
}

module appService 'modules/app-service.bicep' = {
  name: 'appServiceDeploy'
  params: {
    location: location
    appServicePlanName: planName
    appServiceName: appName
    linuxFxVersion: appRuntime
  }
}

module waf 'modules/waf-policy.bicep' = {
  name: 'wafDeploy'
  params: {
    wafPolicyName: wafName
  }
}

module frontDoor 'modules/front-door.bicep' = {
  name: 'frontDoorDeploy'
  params: {
    profileName: frontDoorName
    endpointName: endpointName
    appServiceId: appService.outputs.appServiceId
    appServiceHostname: appService.outputs.appServiceHostname
    originLocation: location
    wafPolicyId: waf.outputs.wafPolicyId
  }
}

module diagnostics 'modules/diagnostics.bicep' = {
  name: 'diagnosticsDeploy'
  params: {
    frontDoorProfileName: frontDoor.outputs.profileName
    appServiceName: appService.outputs.appServiceName
    workspaceId: logAnalytics.outputs.workspaceId
  }
}

output frontDoorHostname string = frontDoor.outputs.endpointHostname
output appServiceId string = appService.outputs.appServiceId
output appServiceName string = appService.outputs.appServiceName
output appServiceHostname string = appService.outputs.appServiceHostname
output logAnalyticsWorkspaceName string = logAnalytics.outputs.workspaceName
