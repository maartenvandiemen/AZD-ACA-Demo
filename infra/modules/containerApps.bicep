@description('The tags to associate with the resource')
param tags object

@description('Name of the ACR to use in the same resource group')
param acrName string

@description('Resource ID of the user-assigned identity (with AcrPull on the registry) used to pull the image')
param pullIdentityId string

var uniqueName = uniqueString(resourceGroup().id, subscription().id)

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: acrName
}

resource environment 'Microsoft.App/managedEnvironments@2026-07-01' = {
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

resource app 'Microsoft.App/containerApps@2026-07-01' = {
  location: resourceGroup().location
  tags: tags
  name: 'app-${uniqueName}'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${pullIdentityId}': {}
    }
  }
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
      registries: [
        {
          server: registry.properties.loginServer
          identity: pullIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'container-${uniqueName}'
          image: '${registry.properties.loginServer}/maartenvandiemen/eshoponwebmvc:latest'
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
            {
              // No Seq server is deployed; without this the app fails to start ("Unable to add a Seq health check because the 'ServerUrl' setting is missing")
              name: 'Aspire__Seq__DisableHealthChecks'
              value: 'true'
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

@description('Fully qualified domain name of the container app (HTTPS is provided by the Container Apps ingress)')
output fqdn string = app.properties.configuration.ingress.fqdn
