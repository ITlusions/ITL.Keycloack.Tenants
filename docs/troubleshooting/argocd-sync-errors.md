# ArgoCD Sync Errors

This guide covers common ArgoCD sync errors and their solutions when deploying ITL Keycloak Tenants.

## Common Sync Errors

### 1. ConfigMap Not Found Error

**Error Message:**
```
Failed to load target state: failed to generate manifest for source 1 of 1: 
rpc error: code = Unknown desc = Manifest generation error (cached): 
`helm template . --name-template itl-keycloak-tenants --namespace itl-keycloack-tenants 
--kube-version 1.30 --values <path>/tenants/itlkc01.yaml --include-crds` 
failed exit status 1: Error: execution error at (itl.keycloak/charts/modsecurity-crs/templates/common.yaml:1:3): 
Persistence - Expected configmap [modsec-overrides] defined in [objectName] to exist
```

**Root Cause:**
The ModSecurity chart expects a ConfigMap named `modsec-overrides` but it's not being rendered due to:
- Incorrect YAML indentation (tabs instead of spaces)
- Missing `modsecurity.enabled: true` configuration
- Template conditional logic not met

**Solution:**

1. **Fix YAML Indentation:**
   ```yaml
   # Correct indentation (spaces, not tabs)
   {{- if .Values.modsecurity.enabled }}
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: modsec-overrides
     namespace: {{ .Release.Namespace }}
     labels:
       app.kubernetes.io/name: modsecurity-overrides
       app.kubernetes.io/instance: {{ .Release.Name }}
   data:
     modsec-ignore-healthz.conf: |
       SecRule REQUEST_URI "@beginsWith /healthz" \
           "id:999001,phase:1,pass,nolog,ctl:ruleRemoveById=920350"
   {{- end }}
   ```

2. **Enable ModSecurity in values.yaml:**
   ```yaml
   modsecurity:
     enabled: true
   ```

3. **Verify tenant configuration:**
   ```yaml
   # In tenants/tenant-name.yaml
   modsecurity:
     enabled: true
   
   modsecurity-crs:
     enabled: true
     persistence:
       modsecurity-custom-rules:
         enabled: true
         type: configmap
         objectName: modsec-overrides
         mountPath: /etc/modsecurity.d/custom
   ```

### 2. Namespace Creation Issues

**Error Message:**
```
Operation cannot be fulfilled on namespaces "itl-keycloack-tenants": 
the object has been modified
```

**Solution:**
Add the `CreateNamespace=true` sync option:

```yaml
syncPolicy:
  syncOptions:
  - CreateNamespace=true
  - ServerSideApply=true
```

### 3. Resource Validation Errors

**Error Message:**
```
error validating data: ValidationError(Keycloak.spec): unknown field "instances"
```

**Root Cause:**
Keycloak CRD version mismatch or missing CRD installation.

**Solution:**

1. **Install Keycloak Operator:**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-extensions/main/operator/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
   ```

2. **Verify CRD version:**
   ```bash
   kubectl get crd keycloaks.k8s.keycloak.org -o yaml
   ```

3. **Update Keycloak resource spec:**
   ```yaml
   apiVersion: k8s.keycloak.org/v2alpha1
   kind: Keycloak
   metadata:
     name: {{ .Values.keycloak.name }}
   spec:
     instances: {{ .Values.keycloak.instances | default 1 }}
   ```

### 4. Certificate Issues

**Error Message:**
```
error syncing 'Certificate.cert-manager.io': 
Certificate.cert-manager.io "tenant-tls" is invalid: 
spec.dnsNames[0]: Invalid value: "": must not be empty
```

**Solution:**

1. **Fix certificate configuration:**
   ```yaml
   certificate:
     enabled: true
     issuer: "letsencrypt-issuer"
     dnsNames:
       - {{ .Values.keycloak.hostname.hostname }}
       {{- range .Values.certificate.additionalDnsNames }}
       - {{ . }}
       {{- end }}
   ```

2. **Verify cert-manager installation:**
   ```bash
   kubectl get pods -n cert-manager
   ```

### 5. Database Connection Errors

**Error Message:**
```
Keycloak pod failing with: 
WARN [org.hibernate.engine.jdbc.env.internal.JdbcEnvironmentInitiator] 
HHH000342: Could not obtain connection to query metadata
```

**Solution:**

1. **Check database secrets:**
   ```bash
   kubectl get secret keycloak-db-secret -o yaml
   ```

2. **Verify database configuration:**
   ```yaml
   keycloak:
     db:
       vendor: postgres
       host: postgres-db
       usernameSecret:
         name: keycloak-db-secret
         key: username
       passwordSecret:
         name: keycloak-db-secret
         key: password
   ```

3. **Test database connectivity:**
   ```bash
   kubectl run postgres-test --rm -i --tty --image postgres:15 -- \
     psql -h postgres-db -U keycloak
   ```

## Diagnostic Commands

### 1. Application Status

```bash
# Get application details
argocd app get itl-keycloak-tenants

# View sync status
argocd app sync itl-keycloak-tenants --dry-run

# Check application logs
argocd app logs itl-keycloak-tenants
```

### 2. Resource Inspection

```bash
# List all resources
kubectl get all -n itl-keycloack-tenants

# Check resource events
kubectl get events -n itl-keycloack-tenants --sort-by='.lastTimestamp'

# Describe problematic resources
kubectl describe pod <pod-name> -n itl-keycloack-tenants
```

### 3. Helm Template Validation

```bash
# Test Helm template locally
helm template . --values tenants/itlkc01.yaml --debug

# Validate specific template
helm template . --values tenants/itlkc01.yaml --show-only templates/modsecurity-configmap.yaml
```

### 4. ArgoCD Server Logs

```bash
# Check ArgoCD application controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# Check ArgoCD repo server logs
kubectl logs -n argocd deployment/argocd-repo-server
```

## Prevention Strategies

### 1. Pre-commit Validation

Create a pre-commit hook to validate Helm templates:

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Validate Helm templates
for tenant_file in tenants/*.yaml; do
    echo "Validating $tenant_file..."
    helm template . --values "$tenant_file" --dry-run
    if [ $? -ne 0 ]; then
        echo "Helm template validation failed for $tenant_file"
        exit 1
    fi
done
```

### 2. CI/CD Pipeline Checks

```yaml
# .github/workflows/validate.yml
name: Validate Helm Templates
on:
  pull_request:
    paths:
      - 'templates/**'
      - 'tenants/**'
      - 'values.yaml'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Helm
      uses: azure/setup-helm@v3
      with:
        version: '3.12.0'
    
    - name: Validate templates
      run: |
        for tenant in tenants/*.yaml; do
          helm template . --values "$tenant" --validate
        done
```

### 3. Monitoring and Alerting

```yaml
# ArgoCD sync failure alert
- alert: ArgoCDSyncFailure
  expr: argocd_app_sync_total{phase="Failed"} > 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "ArgoCD sync failure for {{ $labels.name }}"
    description: "Application {{ $labels.name }} has failed to sync"
```

## Recovery Procedures

### 1. Manual Sync Recovery

```bash
# Force sync with replace
argocd app sync itl-keycloak-tenants --force --replace

# Sync specific resource
argocd app sync itl-keycloak-tenants --resource apps:Deployment:keycloak
```

### 2. Rollback to Previous Version

```bash
# List application history
argocd app history itl-keycloak-tenants

# Rollback to specific revision
argocd app rollback itl-keycloak-tenants --revision 5
```

### 3. Hard Reset

```bash
# Delete application and recreate
argocd app delete itl-keycloak-tenants
argocd app create -f application.yaml
```

## Best Practices

1. **Always validate templates locally before committing**
2. **Use proper YAML indentation (spaces, not tabs)**
3. **Enable all required dependencies in values.yaml**
4. **Test in staging environment first**
5. **Monitor ArgoCD application health**
6. **Set up proper alerting for sync failures**
7. **Document custom configurations**
8. **Regular backup of ArgoCD applications**