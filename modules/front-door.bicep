@description('Front Door profile name.')
param profileName string

@description('Endpoint name (becomes <name>-<hash>.z01.azurefd.net).')
param endpointName string

@description('Origin group name.')
param originGroupName string = 'app-origin-group'

@description('Origin name.')
param originName string = 'app-origin'

@description('Route name.')
param routeName string = 'default-route'

@description('Security policy name (associates WAF with the endpoint).')
param securityPolicyName string = 'default-security-policy'

@description('Resource ID of the App Service origin (for Private Link).')
param appServiceId string

@description('Default hostname of the App Service (e.g. mysite.azurewebsites.net).')
param appServiceHostname string

@description('Region where the App Service lives (used for Private Link).')
param originLocation string

@description('Resource ID of the WAF policy to attach.')
param wafPolicyId string

resource profile 'Microsoft.Cdn/profiles@2024-02-01' = {
  name: profileName
  location: 'Global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' = {
  parent: profile
  name: endpointName
  location: 'Global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = {
  parent: profile
  name: originGroupName
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 30
    }
    sessionAffinityState: 'Disabled'
  }
}

resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  parent: originGroup
  name: originName
  properties: {
    hostName: appServiceHostname
    originHostHeader: appServiceHostname
    httpPort: 80
    httpsPort: 443
    enforceCertificateNameCheck: true
    enabledState: 'Enabled'
    priority: 1
    weight: 1000
    sharedPrivateLinkResource: {
      privateLink: {
        id: appServiceId
      }
      groupId: 'sites'
      privateLinkLocation: originLocation
      requestMessage: 'Front Door Premium origin link'
    }
  }
}

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  parent: endpoint
  name: routeName
  dependsOn: [
    origin
  ]
  properties: {
    originGroup: {
      id: originGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2024-02-01' = {
  parent: profile
  name: securityPolicyName
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicyId
      }
      associations: [
        {
          domains: [
            {
              id: endpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

output profileId string = profile.id
output profileName string = profile.name
output endpointId string = endpoint.id
output endpointHostname string = endpoint.properties.hostName
