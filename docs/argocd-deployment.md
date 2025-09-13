# ArgoCD Deployment Guide

This guide covers deploying ITL Keycloak Tenants using ArgoCD for GitOps workflows.

## Prerequisites

- ArgoCD installed and configured
- Access to the target Kubernetes cluster
- Git repository with Helm chart and tenant configurations

## ArgoCD Application Configuration

### Basic Application Manifest

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: itl-keycloak-tenants
  namespace: argocd
spec:
  destination:
    namespace: itl-keycloack-tenants
    server: https://kubernetes.default.svc
  project: default
  source:
    helm:
      valueFiles:
      - tenants/itlkc01.yaml
    path: .
    repoURL: https://github.com/ITlusions/ITL.Keycloack.Tenants.git
    targetRevision: main
  syncPolicy:
    automated:
      prune: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    - ApplyOutOfSyncOnly=true
```

### Multiple Tenant Deployment

For deploying multiple tenants, create separate applications:

```yaml
# Tenant 1
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak-tenant-prod
  namespace: argocd
spec:
  destination:
    namespace: keycloak-tenant-prod
    server: https://kubernetes.default.svc
  project: default
  source:
    helm:
      valueFiles:
      - tenants/prod.yaml
    path: .
    repoURL: https://github.com/ITlusions/ITL.Keycloack.Tenants.git
    targetRevision: main
  syncPolicy:
    automated:
      prune: true
    syncOptions:
    - CreateNamespace=true

---
# Tenant 2
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak-tenant-staging
  namespace: argocd
spec:
  destination:
    namespace: keycloak-tenant-staging
    server: https://kubernetes.default.svc
  project: default
  source:
    helm:
      valueFiles:
      - tenants/staging.yaml
    path: .
    repoURL: https://github.com/ITlusions/ITL.Keycloack.Tenants.git
    targetRevision: main
  syncPolicy:
    automated:
      prune: true
    syncOptions:
    - CreateNamespace=true
```

## Sync Policies

### Automated Sync

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

### Manual Sync

```yaml
syncPolicy:
  # No automated sync policy
  syncOptions:
  - CreateNamespace=true
  - ServerSideApply=true
```

## Sync Options

| Option | Description | Use Case |
|--------|-------------|----------|
| `CreateNamespace=true` | Create namespace if it doesn't exist | New deployments |
| `ServerSideApply=true` | Use server-side apply | Large manifests |
| `ApplyOutOfSyncOnly=true` | Only apply out-of-sync resources | Performance optimization |
| `PrunePropagationPolicy=background` | Background deletion | Faster pruning |
| `PruneLast=true` | Prune after apply | Dependency ordering |

## Application Projects

### Dedicated Project

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: keycloak-tenants
  namespace: argocd
spec:
  description: "Keycloak tenant deployments"
  
  # Source repositories
  sourceRepos:
  - 'https://github.com/ITlusions/ITL.Keycloack.Tenants.git'
  
  # Allowed destinations
  destinations:
  - namespace: 'itl-keycloack-*'
    server: https://kubernetes.default.svc
  - namespace: 'keycloak-*'
    server: https://kubernetes.default.svc
  
  # Cluster resource whitelist
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  - group: 'apiextensions.k8s.io'
    kind: CustomResourceDefinition
  
  # Namespace resource whitelist
  namespaceResourceWhitelist:
  - group: ''
    kind: '*'
  - group: 'apps'
    kind: '*'
  - group: 'networking.k8s.io'
    kind: '*'
  - group: 'cert-manager.io'
    kind: '*'
  - group: 'k8s.keycloak.org'
    kind: '*'
```

## Git Repository Structure

```
ITL.Keycloack.Tenants/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── ...
├── tenants/
│   ├── prod.yaml
│   ├── staging.yaml
│   └── dev.yaml
└── charts/
    └── modsecurity-crs/
```

## Environment-Specific Configurations

### Production Tenant

```yaml
# tenants/prod.yaml
modsecurity:
  enabled: true
  proxy:
    replicaCount: 3
    resources:
      limits:
        cpu: 1000m
        memory: 1Gi

keycloak:
  name: keycloak-prod
  instances: 3
  hostname:
    hostname: auth.company.com
  
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
```

### Staging Tenant

```yaml
# tenants/staging.yaml
modsecurity:
  enabled: true
  proxy:
    replicaCount: 1
    resources:
      limits:
        cpu: 500m
        memory: 512Mi

keycloak:
  name: keycloak-staging
  instances: 1
  hostname:
    hostname: auth-staging.company.com
```

## Health Checks and Sync Status

### Application Health

ArgoCD monitors the health of deployed resources:

```yaml
# Custom health check for Keycloak
resource.customizations.health.k8s.keycloak.org_Keycloak: |
  hs = {}
  if obj.status ~= nil then
    if obj.status.conditions ~= nil then
      for i, condition in ipairs(obj.status.conditions) do
        if condition.type == "Ready" and condition.status == "True" then
          hs.status = "Healthy"
          hs.message = "Keycloak is ready"
          return hs
        end
      end
    end
  end
  hs.status = "Progressing"
  hs.message = "Waiting for Keycloak to be ready"
  return hs
```

### Sync Waves

Control deployment order using sync waves:

```yaml
# Database first (wave 0)
apiVersion: v1
kind: Secret
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"

# ModSecurity second (wave 1)
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"

# Keycloak last (wave 2)
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
```

## Rollback Strategies

### Automatic Rollback

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  retry:
    limit: 3
    backoff:
      duration: 5s
      factor: 2
```

### Manual Rollback

```bash
# List application history
argocd app history itl-keycloak-tenants

# Rollback to specific revision
argocd app rollback itl-keycloak-tenants --revision 5
```

## Monitoring and Alerts

### Application Metrics

```yaml
# ServiceMonitor for ArgoCD metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
```

### Sync Failure Alerts

```yaml
# PrometheusRule for sync failures
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: argocd-sync-alerts
spec:
  groups:
  - name: argocd
    rules:
    - alert: ArgoCDSyncFailure
      expr: argocd_app_sync_total{phase="Failed"} > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "ArgoCD sync failure"
        description: "Application {{ $labels.name }} sync has failed"
```

## Troubleshooting

### Common Sync Issues

1. **Resource Validation Errors**
   ```bash
   # Check application details
   argocd app get itl-keycloak-tenants
   
   # View sync status
   argocd app sync itl-keycloak-tenants --dry-run
   ```

2. **Helm Template Errors**
   ```bash
   # Test Helm template locally
   helm template . --values tenants/prod.yaml --debug
   ```

3. **Resource Conflicts**
   ```bash
   # Force sync with replace
   argocd app sync itl-keycloak-tenants --force
   ```

### Debug Commands

```bash
# Application logs
argocd app logs itl-keycloak-tenants

# Resource details
argocd app resources itl-keycloak-tenants

# Sync with verbose output
argocd app sync itl-keycloak-tenants --verbose
```

## Best Practices

1. **Use App of Apps Pattern**
   - Deploy multiple tenant applications
   - Centralized management
   - Environment isolation

2. **Resource Quotas**
   - Set namespace resource limits
   - Monitor resource usage
   - Prevent resource exhaustion

3. **Security**
   - Use RBAC for ArgoCD access
   - Separate projects for environments
   - Audit application changes

4. **Testing**
   - Validate Helm templates
   - Test in staging first
   - Use sync waves for dependencies