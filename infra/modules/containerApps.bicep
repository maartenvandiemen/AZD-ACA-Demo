@description('The tags to associate with the resource')
param tags object

@description('Name of the ACR to use in the same resource group')
param acrName string

var uniqueName = uniqueString(resourceGroup().id, subscription().id)

resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: acrName
}

resource environment 'Microsoft.App/managedEnvironments@2024-10-02-preview' = {
  location: resourceGroup().location
  tags: tags
  name: 'env-${uniqueName}'
  properties: {
    zoneRedundant: false
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
      }
    ]
  }
}

resource app 'Microsoft.App/containerApps@2024-10-02-preview' = {
  location: resourceGroup().location
  tags: tags
  name: 'app-${uniqueName}'
  properties: {
    managedEnvironmentId: environment.id
    environmentId: environment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
      }
      secrets:[
        {
          name: 'secret1'
          value: registry.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: registry.properties.loginServer
          username: registry.listCredentials().username
          passwordSecretRef: 'secret1'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'container-${uniqueName}'
          image: '${registry.properties.loginServer}/maartenvandiemen/eshoponweb:latest'
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Docker'
            }
            {
              name: 'UseOnlyInMemoryDatabase'
              value: 'true'
            }
            {
              name: 'ASPNETCORE_HTTP_PORTS'
              value: '80'
            }
          ]
          resources: {
              cpu: 1
              memory: '2Gi'
          }
        }
      ]
    }
  }
}
