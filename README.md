# Keycloak Multi-Tenant Helm Chart

This Helm chart deploys a production-ready, multi-tenant [Keycloak](https://www.keycloak.org/) cluster on Kubernetes. It is designed to provide secure, scalable, and highly available identity and access management for multiple tenants (realms) using a single Keycloak deployment.

## Features

- **Multi-Tenant Support:** Manage multiple realms (tenants) within a single Keycloak instance.
- **External PostgreSQL Integration:** Connects Keycloak to an external PostgreSQL database for reliable data storage.
- **Automated TLS with cert-manager:** Integrates with cert-manager and Let’s Encrypt to automatically provision and renew TLS certificates for secure HTTPS access.
- **Flexible Hostname/DNS Configuration:** Supports custom hostnames and multiple DNS names for SSO endpoints (e.g., `auth.example.com`, `login.example.com`).
- **Ingress Integration:** Easily expose Keycloak via your preferred ingress controller (e.g., Traefik, NGINX) with configurable ingress class.
- **Secure Secret Management:** Database credentials and admin credentials are stored securely in Kubernetes Secrets, generated and managed by the chart.
- **Customizable:** All Keycloak, database, and ingress settings are configurable via `values.yaml`.

## Prerequisites

- Kubernetes 1.20+
- Helm 3.0+
- [cert-manager](https://cert-manager.io/) (for automated TLS)
- An external PostgreSQL database (or managed Postgres service)
- An ingress controller (e.g., Traefik, NGINX)

## Installation

To install the chart, use the following command:

```bash
helm install <release-name> .
```

Replace `<release-name>` with your desired release name.

## Configuration

Configure tenants and Keycloak settings in your `values.yaml`. Example:

```yaml
keycloak:
  name: mytenant
  instances: 2
  db:
    vendor: postgres
    host: mytenant-postgres
    usernameSecret:
      name: keycloak-db-secret
      key: username
    passwordSecret:
      name: keycloak-db-secret
      key: password
  http:
    tlsSecret: mytenant-tls
  hostname:
    hostname: auth.example.com
  proxy:
    headers: xforwarded
  externalAccess:
    enabled: true

certificate:
  additionalDnsNames:
    - login.example.com
    - sso.example.com
```

You can override these values by specifying them in a `values.yaml` file or directly in the command line using `--set`.

## Accessing Keycloak

After deployment, retrieve the initial admin credentials:

```bash
kubectl get secret <release-name>-<tenant-name>-initial-admin -o jsonpath="{.data.username}" | base64 --decode
kubectl get secret <release-name>-<tenant-name>-initial-admin -o jsonpath="{.data.password}" | base64 --decode
```

Access the Keycloak admin console at:  
`https://<your-configured-hostname>/admin/`

## Uninstalling the Chart

To uninstall the chart, use the following command:

```bash
helm uninstall <release-name>
```

## Notes

- For advanced configuration, see the chart's `templates/` and `values.yaml`.
- This chart is suitable for production and development environments.
- For more details on Keycloak multi-tenancy, see the [Keycloak documentation](https://www.keycloak.org/documentation).

---
<br>


**Niels Weistra** at **n.weistra@itlusions.com**.

[![LinkedIn](https://img.shields.io/badge/LinkedIn-blue?logo=linkedin&logoColor=white)](https://nl.linkedin.com/in/nielswei)