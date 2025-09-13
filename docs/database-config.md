# Database Configuration

This guide covers PostgreSQL database configuration for ITL Keycloak Tenants.

## Default Configuration

### PostgreSQL Database

```yaml
# Default database configuration
database:
  enabled: true
  vendor: postgres
  image:
    repository: postgres
    tag: "15"
  
  persistence:
    enabled: true
    size: 10Gi
    storageClass: ""
  
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi
```

### Database Secrets

The chart expects database credentials to be provided via Kubernetes secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-db-secret
  namespace: itl-keycloack-tenants
type: Opaque
data:
  username: a2V5Y2xvYWs=  # base64 encoded 'keycloak'
  password: <base64-encoded-password>
```

## Connection Configuration

### Keycloak Database Connection

```yaml
keycloak:
  db:
    vendor: postgres
    host: postgres-db
    port: 5432
    database: keycloak
    usernameSecret:
      name: keycloak-db-secret
      key: username
    passwordSecret:
      name: keycloak-db-secret
      key: password
    
    # Additional connection parameters
    parameters:
      ssl: false
      connectTimeout: 30
```

### Connection Pool Settings

```yaml
keycloak:
  env:
    - name: KC_DB_POOL_INITIAL_SIZE
      value: "5"
    - name: KC_DB_POOL_MIN_SIZE
      value: "5"
    - name: KC_DB_POOL_MAX_SIZE
      value: "20"
```

## High Availability Setup

### PostgreSQL Cluster

For production deployments, consider using a PostgreSQL cluster:

```yaml
# Using CloudNativePG operator
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-cluster
  namespace: itl-keycloack-tenants
spec:
  instances: 3
  primaryUpdateStrategy: unsupervised
  
  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      work_mem: "4MB"
  
  storage:
    size: 20Gi
    storageClass: fast-ssd
  
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

### Read Replicas

```yaml
# Read replica for reporting
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-replica
spec:
  instances: 1
  
  replica:
    enabled: true
    source: postgres-cluster
```

## Backup and Recovery

### Automated Backups

```yaml
# Backup configuration
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  backupOwnerReference: self
  cluster:
    name: postgres-cluster
  
  retentionPolicy: "30d"
  
  # S3 backup destination
  s3Credentials:
    accessKeyId:
      name: backup-credentials
      key: ACCESS_KEY_ID
    secretAccessKey:
      name: backup-credentials
      key: SECRET_ACCESS_KEY
    region:
      name: backup-credentials
      key: DEFAULT_REGION
    bucket:
      name: backup-credentials
      key: BUCKET_NAME
```

### Manual Backup

```bash
# Create manual backup
kubectl exec -it postgres-cluster-1 -- pg_dump \
  -h localhost -U keycloak -d keycloak > keycloak-backup.sql

# Restore from backup
kubectl exec -i postgres-cluster-1 -- psql \
  -h localhost -U keycloak -d keycloak < keycloak-backup.sql
```

## Performance Tuning

### PostgreSQL Configuration

```yaml
postgresql:
  parameters:
    # Memory settings
    shared_buffers: "256MB"
    effective_cache_size: "1GB"
    work_mem: "4MB"
    maintenance_work_mem: "64MB"
    
    # Connection settings
    max_connections: "200"
    
    # WAL settings
    wal_buffers: "16MB"
    checkpoint_completion_target: "0.9"
    
    # Query planner
    random_page_cost: "1.1"
    effective_io_concurrency: "200"
```

### Resource Allocation

```yaml
database:
  resources:
    requests:
      cpu: "1000m"
      memory: "2Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"
  
  # Storage configuration
  persistence:
    size: 50Gi
    storageClass: "fast-ssd"
```

## Security Configuration

### Authentication

```yaml
postgresql:
  parameters:
    # SSL configuration
    ssl: "on"
    ssl_cert_file: "/etc/ssl/certs/server.crt"
    ssl_key_file: "/etc/ssl/private/server.key"
    
    # Authentication
    password_encryption: "scram-sha-256"
    
    # Connection logging
    log_connections: "on"
    log_disconnections: "on"
```

### Network Security

```yaml
# Network policy for database access
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-netpol
  namespace: itl-keycloack-tenants
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: keycloak
    ports:
    - protocol: TCP
      port: 5432
```

## Monitoring

### Database Metrics

```yaml
# PostgreSQL exporter
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-exporter
spec:
  template:
    spec:
      containers:
      - name: postgres-exporter
        image: prometheuscommunity/postgres-exporter:latest
        env:
        - name: DATA_SOURCE_NAME
          value: "postgresql://keycloak:password@postgres-db:5432/keycloak?sslmode=disable"
        ports:
        - containerPort: 9187
```

### ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: postgres-metrics
spec:
  selector:
    matchLabels:
      app: postgres-exporter
  endpoints:
  - port: metrics
    interval: 30s
```

## Troubleshooting

### Connection Issues

```bash
# Test database connectivity
kubectl run postgres-test --rm -i --tty --image postgres:15 -- \
  psql -h postgres-db -U keycloak -d keycloak

# Check database logs
kubectl logs -f statefulset/postgresql-db

# View database metrics
kubectl exec -it postgres-cluster-1 -- psql -U postgres -c "
  SELECT 
    datname,
    numbackends,
    xact_commit,
    xact_rollback
  FROM pg_stat_database 
  WHERE datname = 'keycloak';
"
```

### Performance Analysis

```sql
-- Check slow queries
SELECT 
  query,
  calls,
  total_time,
  mean_time,
  rows
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;

-- Check database size
SELECT 
  pg_size_pretty(pg_database_size('keycloak')) as database_size;

-- Check table sizes
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Backup Verification

```bash
# List available backups
kubectl get backups

# Restore to point in time
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-restored
spec:
  instances: 1
  
  bootstrap:
    recovery:
      backup:
        name: postgres-backup-20240914
      recoveryTargetTime: "2024-09-14 10:00:00"
EOF
```

## Best Practices

1. **Use dedicated database users for each tenant**
2. **Implement regular backup schedules**
3. **Monitor database performance metrics**
4. **Use connection pooling**
5. **Enable SSL for production**
6. **Regular security updates**
7. **Proper resource allocation**
8. **Database schema versioning**