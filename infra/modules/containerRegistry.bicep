@description('The tags to associate with the resource')
param tags object

var uniqueName = uniqueString(resourceGroup().id, subscription().id)
var registryName = 'acr${uniqueName}'

resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: registryName
  location: resourceGroup().location
  properties: {
    adminUserEnabled: true
  }
  tags: tags
  sku: {
    name: 'Basic'
  }
}

var identityName = 'identity-${uniqueName}'

resource userId 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  location: resourceGroup().location
  name: identityName
  tags: tags
}

resource roleAssignmentACR 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: registry
  name: guid(registryName, resourceGroup().id, userId.id, 'Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: userId.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentRG 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().name, resourceGroup().id, userId.id, 'Reader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
    principalId: userId.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'ImportImageScript'
  location: resourceGroup().location
  dependsOn: [roleAssignmentACR]
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {      
      '${userId.id}' : {}
    }
  }
  properties: {
    azCliVersion: '2.63.0' //There must a better way to automatically use latest instead of keep on updating the version.
    scriptContent: 'az acr import --name ${registryName} --source ghcr.io/maartenvandiemen/eshoponweb:latest --image maartenvandiemen/eshoponweb:latest'
    retentionInterval: 'PT1H'
  }
}

output registryName string = registry.name
