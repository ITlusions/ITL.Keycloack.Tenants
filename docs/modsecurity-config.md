# ModSecurity Configuration

This guide covers the ModSecurity Web Application Firewall configuration in the ITL Keycloak Tenants chart.

## Overview

ModSecurity provides web application protection using the OWASP Core Rule Set (CRS). It acts as a reverse proxy in front of Keycloak instances, filtering malicious requests.

## Basic Configuration

### Enabling ModSecurity

```yaml
modsecurity:
  enabled: true
  proxy:
    replicaCount: 2
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 250m
        memory: 256Mi
```

### Service Configuration

```yaml
modsecurity:
  proxy:
    service:
      main:
        ports:
          https:
            enabled: true
            port: 8443
            targetPort: 8443
            protocol: TCP
```

## ModSecurity CRS Configuration

### Default Rule Set

The chart uses OWASP ModSecurity CRS with the following configuration:

```yaml
modsecurity-crs:
  enabled: true
  image:
    repository: docker.io/owasp/modsecurity-crs
    tag: 3.3.4-apache-202307110507
  
  persistence:
    modsecurity-custom-rules:
      enabled: true
      type: configmap
      objectName: modsec-overrides
      mountPath: /etc/modsecurity.d/custom
```

### Custom Rules and Overrides

Custom rules are defined in the `modsec-overrides` ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: modsec-overrides
data:
  modsec-ignore-healthz.conf: |
    # Ignore health check endpoints
    SecRule REQUEST_URI "@beginsWith /healthz" \
        "id:999001,phase:1,pass,nolog,ctl:ruleRemoveById=920350"
    
    # Ignore Keycloak admin endpoints from certain rules
    SecRule REQUEST_URI "@beginsWith /admin" \
        "id:999002,phase:1,pass,nolog,ctl:ruleRemoveById=921110"
```

## Security Policies

### Rule Exclusions

Common rule exclusions for Keycloak:

```conf
# Allow Keycloak authentication flows
SecRule REQUEST_URI "@beginsWith /auth/realms" \
    "id:999010,phase:1,pass,nolog,ctl:ruleRemoveById=942100,ctl:ruleRemoveById=942110"

# Allow admin console operations
SecRule REQUEST_URI "@beginsWith /admin/realms" \
    "id:999011,phase:1,pass,nolog,ctl:ruleRemoveById=942100"

# Allow user registration forms
SecRule REQUEST_URI "@beginsWith /auth/realms/*/protocol/openid-connect/registrations" \
    "id:999012,phase:1,pass,nolog,ctl:ruleRemoveById=942100"
```

### Rate Limiting

```conf
# Rate limiting for login attempts
SecRule REQUEST_URI "@beginsWith /auth/realms/*/protocol/openid-connect/token" \
    "id:999020,phase:1,pass,nolog,setvar:ip.login_attempts=+1"

SecRule IP:LOGIN_ATTEMPTS "@gt 10" \
    "id:999021,phase:1,deny,status:429,msg:'Rate limit exceeded'"
```

## Environment Variables

### ModSecurity Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `MODSEC_DATA_DIR` | ModSecurity data directory | `/modsecurity/data` |
| `MODSEC_TMP_DIR` | ModSecurity temp directory | `/modsecurity/temp` |
| `MODSEC_UPLOAD_DIR` | ModSecurity upload directory | `/modsecurity/upload` |
| `PORT` | HTTP port | `8081` |
| `SSL_PORT` | HTTPS port | `8443` |

### Apache Configuration

```yaml
modsecurity-crs:
  workload:
    main:
      podSpec:
        containers:
          main:
            env:
              APACHE_TIMEOUT: "60"
              APACHE_KEEPALIVE_TIMEOUT: "15"
              APACHE_MAX_KEEP_ALIVE_REQUESTS: "100"
```

## Performance Tuning

### Resource Allocation

```yaml
modsecurity:
  proxy:
    resources:
      limits:
        cpu: 1000m
        memory: 1Gi
      requests:
        cpu: 500m
        memory: 512Mi
```

### Horizontal Pod Autoscaling

```yaml
modsecurity:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

### Persistence Configuration

```yaml
modsecurity-crs:
  persistence:
    data:
      enabled: true
      type: emptyDir
      size: 1Gi
    temp:
      enabled: true
      type: emptyDir
      size: 500Mi
    upload:
      enabled: true
      type: emptyDir
      size: 500Mi
```

## Security Context

### Container Security

```yaml
modsecurity-crs:
  securityContext:
    container:
      runAsNonRoot: false  # Apache requires root for port binding
      readOnlyRootFilesystem: false
      runAsUser: 0
      runAsGroup: 0
      capabilities:
        drop:
          - ALL
        add:
          - NET_BIND_SERVICE
```

### Pod Security Standards

```yaml
modsecurity-crs:
  podSecurityContext:
    seccompProfile:
      type: RuntimeDefault
    sysctls:
      - name: net.core.somaxconn
        value: "65535"
```

## Monitoring and Logging

### Health Checks

```yaml
modsecurity-crs:
  workload:
    main:
      podSpec:
        containers:
          main:
            probes:
              liveness:
                httpGet:
                  path: "/healthz"
                  port: 8081
                initialDelaySeconds: 30
                periodSeconds: 10
              readiness:
                httpGet:
                  path: "/healthz"
                  port: 8081
                initialDelaySeconds: 5
                periodSeconds: 5
```

### Audit Logging

```conf
# Enable audit logging for blocked requests
SecAuditEngine On
SecAuditLogType Serial
SecAuditLogFormat JSON
SecAuditLog /var/log/modsec_audit.log

# Log only blocked requests
SecAuditLogParts ABIJDEFHZ
SecAuditLogRelevantStatus "^(?:5|4(?!04))"
```

### Metrics Collection

```yaml
modsecurity-crs:
  serviceMonitor:
    enabled: true
    labels:
      prometheus: kube-prometheus
    interval: 30s
    path: /metrics
```

## Troubleshooting

### Common Issues

1. **False Positives**
   - Review ModSecurity audit logs
   - Create specific rule exclusions
   - Adjust paranoia level

2. **Performance Issues**
   - Monitor CPU and memory usage
   - Optimize rule sets
   - Adjust worker processes

3. **Configuration Errors**
   - Validate ModSecurity syntax
   - Check Apache error logs
   - Test rule sets in permissive mode

### Debug Configuration

```conf
# Enable debug logging
SecDebugLog /var/log/modsec_debug.log
SecDebugLogLevel 9

# Test mode (log only, don't block)
SecRuleEngine DetectionOnly
```

### Log Analysis

```bash
# View blocked requests
kubectl logs -f deployment/modsecurity-crs | grep "ModSecurity: Warning"

# Check audit logs
kubectl exec -it pod/modsecurity-crs-xxx -- tail -f /var/log/modsec_audit.log

# Monitor performance
kubectl top pods -l app=modsecurity-crs
```

## Best Practices

1. **Start with Detection Mode**
   - Test rules before enforcement
   - Monitor false positive rates
   - Gradually increase paranoia level

2. **Regular Updates**
   - Keep CRS rules updated
   - Monitor security advisories
   - Test updates in staging

3. **Custom Rules**
   - Create application-specific rules
   - Document all exceptions
   - Regular rule review

4. **Performance Monitoring**
   - Monitor request latency
   - Track resource usage
   - Set up alerting