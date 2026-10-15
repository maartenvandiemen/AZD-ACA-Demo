targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string
  
var tags = {
  'azd-env-name': environmentName
  SecurityControl: 'Ignore'
}

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module acr 'modules/containerRegistry.bicep' ={
  name: 'acr'
  scope: rg
  params: {

    tags: tags
  }
}

module aci 'modules/containerApps.bicep' = {
  name: 'aca'
  scope: rg
  params: {
    tags: tags
    acrName: acr.outputs.registryName
    pullIdentityId: acr.outputs.pullIdentityId
  }
}

@description('Public URL of the deployed app. The FQDN is stable and served over HTTPS by the Container Apps ingress.')
output APP_URL string = 'https://${aci.outputs.fqdn}'
