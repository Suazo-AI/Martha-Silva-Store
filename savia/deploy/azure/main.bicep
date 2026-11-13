// SAVIA hub in Azure: central API + database that the branches sync with, backups and owner reports.
// Decision record: savia/docs/deploy/AZURE.md. Checklist: savia/docs/deploy/CHECKLIST.md.
//
// Two passes, both with this one file (resource group scope):
//   1. deployApps=false  -> identities, registry, Key Vault, logs, SQL, Container Apps environment.
//   2. push images to the registry, then deployApps=true with apiImage and migratorImage set.
// No secret is a parameter or an output. The API and the migration job reach SQL with managed identities.

targetScope = 'resourceGroup'

@description('Azure region. Recommended: mexicocentral (closest to Nicaragua). Fallback: southcentralus.')
param location string = resourceGroup().location

@description('Short name used in every resource name.')
@minLength(3)
@maxLength(10)
param prefix string = 'savia'

@description('false on the first pass (no image in the registry yet); true once images are pushed.')
param deployApps bool = false

@description('Hub API image, for example <registry>.azurecr.io/savia-api:<git-sha>.')
param apiImage string = ''

@description('Migration job image, for example <registry>.azurecr.io/savia-migrator:<git-sha>.')
param migratorImage string = ''

@description('Node id of the cloud hub (Savia:Node:NodeId). A GUID chosen once and never reused.')
param hubNodeId string

@description('Azure SQL sku. Cheapest viable start: Basic (5 DTU, 2 GB, 7-day point-in-time restore).')
param sqlSku object = {
  name: 'Basic'
  tier: 'Basic'
  capacity: 5
}

@description('Point-in-time restore window in days. Basic allows 1-7.')
@minValue(1)
@maxValue(35)
param backupRetentionDays int = 7

@description('Backup storage redundancy. Geo survives a regional outage.')
@allowed([
  'Geo'
  'Local'
  'Zone'
])
param backupRedundancy string = 'Geo'

@description('0 = scale to zero when idle (cheapest, cold start). 1 = always warm.')
@minValue(0)
@maxValue(3)
param apiMinReplicas int = 0

@description('GitHub repository allowed to deploy through OIDC (owner/name).')
param githubRepository string = 'Suazo-AI/Martha-Silva-Store'

@description('GitHub environment that holds the manual approval.')
param githubEnvironment string = 'production'

@description('Email that receives alerts.')
param alertEmail string

@description('Log Analytics daily ingestion cap in GB (cost guard).')
@minValue(1)
param logDailyCapGb int = 1

var suffix = take(uniqueString(resourceGroup().id), 6)
var tags = {
  app: 'savia'
  role: 'hub'
}
var databaseName = 'savia'
var roles = {
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  acrPush: '8311e382-0749-4cb8-b61a-304f252e45ec'
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  monitoringMetricsPublisher: '3913510d-42f4-4e42-8a64-420c390055eb'
  contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  sqlDbContributor: '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec'
}

// ---------- Identities ----------

resource apiIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${prefix}-api-${suffix}'
  location: location
  tags: tags
}

// Migration job identity. It is the SQL Entra administrator: it runs DDL and creates the API database user.
resource migratorIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${prefix}-migrate-${suffix}'
  location: location
  tags: tags
}

// GitHub Actions identity. Only the "production" environment of one repository can use it (OIDC, no secret).
resource deployIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${prefix}-deploy-${suffix}'
  location: location
  tags: tags
}

resource githubFederation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: deployIdentity
  name: 'github-${githubEnvironment}'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${githubRepository}:environment:${githubEnvironment}'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

// ---------- Observability ----------

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${prefix}-${suffix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: logDailyCapGb
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${prefix}-${suffix}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logs.id
    DisableLocalAuth: true
    IngestionMode: 'LogAnalytics'
  }
}

// ---------- Registry and secrets ----------

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acr${prefix}${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

// Holds future secrets (branch node credentials, payment keys). Nothing in SAVIA needs a secret today:
// SQL uses managed identities. Access is by Azure RBAC only.
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${prefix}-${suffix}'
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
  }
}

// ---------- Azure SQL ----------

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: 'sql-${prefix}-${suffix}'
  location: location
  tags: tags
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      principalType: 'Application'
      login: migratorIdentity.name
      sid: migratorIdentity.properties.clientId
      tenantId: subscription().tenantId
    }
  }
}

// Only Azure-hosted callers (the Container Apps) reach the server; branches talk to the API, never to SQL.
resource sqlAllowAzure 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource database 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: databaseName
  location: location
  tags: tags
  sku: sqlSku
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    requestedBackupStorageRedundancy: backupRedundancy
  }
}

resource backupPolicy 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2021-11-01' = {
  parent: database
  name: 'default'
  properties: {
    retentionDays: backupRetentionDays
  }
}

resource databaseDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: database
  name: 'to-log-analytics'
  properties: {
    workspaceId: logs.id
    logs: [
      {
        category: 'Errors'
        enabled: true
      }
      {
        category: 'Timeouts'
        enabled: true
      }
      {
        category: 'Blocks'
        enabled: true
      }
      {
        category: 'Deadlocks'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Basic'
        enabled: true
      }
    ]
  }
}

// ---------- Container Apps ----------

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${prefix}-${suffix}'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logs.properties.customerId
        sharedKey: logs.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

var sqlConnectionBase = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${databaseName};Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connect Timeout=30'
var apiSqlConnection = '${sqlConnectionBase};User Id=${apiIdentity.properties.clientId}'
var migratorSqlConnection = '${sqlConnectionBase};User Id=${migratorIdentity.properties.clientId}'

resource api 'Microsoft.App/containerApps@2024-03-01' = if (deployApps) {
  name: 'ca-${prefix}-api'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${apiIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      // Multiple: a new revision starts with 0% traffic, is smoke-tested on its own URL, then promoted.
      activeRevisionsMode: 'Multiple'
      maxInactiveRevisions: 10
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: registry.properties.loginServer
          identity: apiIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: apiImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'Savia__Node__Kind'
              value: 'Cloud'
            }
            {
              name: 'Savia__Node__NodeId'
              value: hubNodeId
            }
            {
              name: 'Savia__Sql__ConnectionString'
              value: apiSqlConnection
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: apiIdentity.properties.clientId
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
          ]
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: 8080
              }
              periodSeconds: 3
              failureThreshold: 20
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              periodSeconds: 10
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              periodSeconds: 30
            }
          ]
        }
      ]
      scale: {
        minReplicas: apiMinReplicas
        maxReplicas: 2
        rules: [
          {
            name: 'http'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    apiAcrPull
  ]
}

// One-off migration job, started by the deploy workflow (or migrate.ps1) before a new revision gets traffic.
resource migrateJob 'Microsoft.App/jobs@2024-03-01' = if (deployApps) {
  name: 'caj-${prefix}-migrate'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${migratorIdentity.id}': {}
    }
  }
  properties: {
    environmentId: environment.id
    configuration: {
      triggerType: 'Manual'
      replicaTimeout: 1800
      replicaRetryLimit: 0
      manualTriggerConfig: {
        parallelism: 1
        replicaCompletionCount: 1
      }
      registries: [
        {
          server: registry.properties.loginServer
          identity: migratorIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'migrate'
          image: migratorImage
          args: [
            '--grant-app-user'
            apiIdentity.name
            '--external'
            '--object-id'
            apiIdentity.properties.principalId
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'Savia__Sql__ConnectionString'
              value: migratorSqlConnection
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: migratorIdentity.properties.clientId
            }
          ]
        }
      ]
    }
  }
  dependsOn: [
    migratorAcrPull
  ]
}

// ---------- Role assignments (least privilege) ----------

resource apiAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: registry
  name: guid(registry.id, apiIdentity.id, roles.acrPull)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
    principalId: apiIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource migratorAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: registry
  name: guid(registry.id, migratorIdentity.id, roles.acrPull)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
    principalId: migratorIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deployAcrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: registry
  name: guid(registry.id, deployIdentity.id, roles.acrPush)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPush)
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource apiSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: vault
  name: guid(vault.id, apiIdentity.id, roles.keyVaultSecretsUser)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
    principalId: apiIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource apiTelemetry 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appInsights
  name: guid(appInsights.id, apiIdentity.id, roles.monitoringMetricsPublisher)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.monitoringMetricsPublisher)
    principalId: apiIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Deploy identity: read the group, update the app and the job, join the environment, copy the database.
resource deployReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deployIdentity.id, roles.reader)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.reader)
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deployEnvironment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: environment
  name: guid(environment.id, deployIdentity.id, roles.contributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.contributor)
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deployApi 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployApps) {
  scope: api
  name: guid(resourceId('Microsoft.App/containerApps', 'ca-${prefix}-api'), deployIdentity.id, roles.contributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.contributor)
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deployJob 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployApps) {
  scope: migrateJob
  name: guid(resourceId('Microsoft.App/jobs', 'caj-${prefix}-migrate'), deployIdentity.id, roles.contributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.contributor)
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deploySqlCopy 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: sqlServer
  name: guid(sqlServer.id, deployIdentity.id, roles.sqlDbContributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.sqlDbContributor)
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------- Alerts ----------

resource owners 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-${prefix}-owner'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'savia'
    enabled: true
    emailReceivers: [
      {
        name: 'owner'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource apiErrorsAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (deployApps) {
  name: 'alert-${prefix}-api-5xx'
  location: 'global'
  tags: tags
  properties: {
    description: 'Hub API returned more than 5 server errors in 5 minutes.'
    severity: 1
    enabled: true
    scopes: [
      api.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'server-errors'
          metricName: 'Requests'
          metricNamespace: 'Microsoft.App/containerApps'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Total'
          dimensions: [
            {
              name: 'statusCodeCategory'
              operator: 'Include'
              values: [
                '5xx'
              ]
            }
          ]
        }
      ]
    }
    actions: [
      {
        actionGroupId: owners.id
      }
    ]
  }
}

resource apiRestartsAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (deployApps) {
  name: 'alert-${prefix}-api-restarts'
  location: 'global'
  tags: tags
  properties: {
    description: 'Hub API container restarted more than 3 times in 15 minutes.'
    severity: 2
    enabled: true
    scopes: [
      api.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'restarts'
          metricName: 'RestartCount'
          metricNamespace: 'Microsoft.App/containerApps'
          operator: 'GreaterThan'
          threshold: 3
          timeAggregation: 'Total'
        }
      ]
    }
    actions: [
      {
        actionGroupId: owners.id
      }
    ]
  }
}

resource sqlStorageAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${prefix}-sql-storage'
  location: 'global'
  tags: tags
  properties: {
    description: 'Hub database is more than 80% full. Basic stops writes at 2 GB.'
    severity: 2
    enabled: true
    scopes: [
      database.id
    ]
    evaluationFrequency: 'PT15M'
    windowSize: 'PT1H'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'storage'
          metricName: 'storage_percent'
          metricNamespace: 'Microsoft.Sql/servers/databases'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Maximum'
        }
      ]
    }
    actions: [
      {
        actionGroupId: owners.id
      }
    ]
  }
}

resource sqlLoadAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${prefix}-sql-load'
  location: 'global'
  tags: tags
  properties: {
    description: 'Hub database above 80% DTU for 15 minutes. Consider S0.'
    severity: 3
    enabled: true
    scopes: [
      database.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'dtu'
          metricName: 'dtu_consumption_percent'
          metricNamespace: 'Microsoft.Sql/servers/databases'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: owners.id
      }
    ]
  }
}

// ---------- Outputs (no secrets) ----------

output registryName string = registry.name
output registryLoginServer string = registry.properties.loginServer
output apiAppName string = deployApps ? api.name : ''
output apiFqdn string = deployApps ? api!.properties.configuration.ingress.fqdn : ''
output migrateJobName string = deployApps ? migrateJob.name : ''
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = database.name
output keyVaultName string = vault.name
output deployClientId string = deployIdentity.properties.clientId
output apiIdentityName string = apiIdentity.name
output tenantId string = subscription().tenantId
