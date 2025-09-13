# Keycloak Configuration

This guide covers the configuration options for Keycloak instances in the ITL Keycloak Tenants chart.

## Basic Configuration

### Tenant Configuration

Each tenant is configured in the `tenants/` directory. Example configuration:

```yaml
keycloak:
  name: tenant-name-prd
  secretNamespace: itl-cnpg-clusters
  instances: 2
  
  db:
    vendor: postgres
    host: postgres-db
    usernameSecret:
      name: keycloak-db-secret
      key: username
    passwordSecret:
      name: keycloak-db-secret
      key: password

  http:
    tlsSecret: tenant-name-prd-tls

  hostname:
    hostname: auth.example.com

  proxy:
    headers: xforwarded

  externalAccess:
    enabled: true
```

## Configuration Options

### Instance Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `keycloak.name` | Name of the Keycloak instance | `""` |
| `keycloak.instances` | Number of Keycloak replicas | `1` |
| `keycloak.secretNamespace` | Namespace for secrets | `default` |

### Database Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `keycloak.db.vendor` | Database vendor (postgres/mysql) | `postgres` |
| `keycloak.db.host` | Database host | `postgres-db` |
| `keycloak.db.usernameSecret.name` | Secret name for DB username | `""` |
| `keycloak.db.usernameSecret.key` | Secret key for DB username | `username` |
| `keycloak.db.passwordSecret.name` | Secret name for DB password | `""` |
| `keycloak.db.passwordSecret.key` | Secret key for DB password | `password` |

### HTTP/HTTPS Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `keycloak.http.tlsSecret` | TLS secret name | `""` |
| `keycloak.hostname.hostname` | Public hostname | `""` |
| `keycloak.proxy.headers` | Proxy headers mode | `xforwarded` |

### External Access

| Parameter | Description | Default |
|-----------|-------------|---------|
| `keycloak.externalAccess.enabled` | Enable external access | `false` |

## Advanced Configuration

### Custom Environment Variables

```yaml
keycloak:
  env:
    - name: KC_LOG_LEVEL
      value: INFO
    - name: KC_METRICS_ENABLED
      value: "true"
```

### Resource Limits

```yaml
keycloak:
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi
```

### Health Checks

```yaml
keycloak:
  health:
    enabled: true
    livenessProbe:
      httpGet:
        path: /health/live
        port: 8080
    readinessProbe:
      httpGet:
        path: /health/ready
        port: 8080
```

## Realm Configuration

Keycloak realms can be configured through:

1. **Init containers** with realm import
2. **Admin API** post-deployment
3. **Keycloak operator** CRDs

### Example Realm Import

```yaml
keycloak:
  initContainers:
    - name: realm-import
      image: keycloak/keycloak:latest
      command:
        - /opt/keycloak/bin/kc.sh
        - import
        - --file=/opt/keycloak/data/import/realm.json
      volumeMounts:
        - name: realm-config
          mountPath: /opt/keycloak/data/import
```

## Security Considerations

### Admin User Configuration

The admin user should be configured through Kubernetes secrets:

```bash
kubectl create secret generic keycloak-admin \
  --from-literal=username=admin \
  --from-literal=password=<secure-password>
```

### Database Security

- Use separate database users for each tenant
- Enable SSL connections to the database
- Regularly rotate database passwords

### Session Configuration

```yaml
keycloak:
  env:
    - name: KC_SPI_STICKY_SESSION_ENCODER_INFINISPAN_SHOULD_ATTACH_ROUTE
      value: "false"
    - name: KC_CACHE_STACK
      value: kubernetes
```

## Monitoring and Observability

### Metrics

Enable Keycloak metrics:

```yaml
keycloak:
  env:
    - name: KC_METRICS_ENABLED
      value: "true"
    - name: KC_HEALTH_ENABLED
      value: "true"
```

### Logging

Configure logging levels:

```yaml
keycloak:
  env:
    - name: KC_LOG_LEVEL
      value: INFO
    - name: QUARKUS_LOG_CATEGORY_ORG_KEYCLOAK_LEVEL
      value: DEBUG
```

## Troubleshooting

### Common Issues

1. **Database Connection Failures**
   - Check database credentials
   - Verify network connectivity
   - Review security group rules

2. **SSL Certificate Issues**
   - Verify cert-manager is working
   - Check DNS resolution
   - Review certificate annotations

3. **Performance Issues**
   - Monitor JVM heap usage
   - Check database query performance
   - Review caching configuration

### Debug Mode

Enable debug mode for troubleshooting:

```yaml
keycloak:
  env:
    - name: KC_LOG_LEVEL
      value: DEBUG
    - name: KEYCLOAK_LOGLEVEL
      value: DEBUG
```