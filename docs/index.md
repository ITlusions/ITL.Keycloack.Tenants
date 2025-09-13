# ITL Keycloak Tenants Documentation

Welcome to the ITL Keycloak Tenants documentation. This Helm chart provides a comprehensive solution for deploying multi-tenant Keycloak instances with ModSecurity protection and PostgreSQL database backends.

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Architecture](#architecture)
4. [Configuration](#configuration)
5. [Deployment](#deployment)
6. [Security](#security)
7. [Troubleshooting](#troubleshooting)
8. [Contributing](#contributing)

## Overview

The ITL Keycloak Tenants chart is designed to deploy secure, scalable Keycloak instances for identity and access management. Each tenant is isolated with its own configuration while sharing common infrastructure components.

### Key Features

- **Multi-tenant Keycloak deployment** with isolated configurations
- **ModSecurity Web Application Firewall** protection
- **PostgreSQL database** backend with high availability
- **SSL/TLS termination** with automatic certificate management
- **Traefik ingress** integration
- **ArgoCD** compatible for GitOps workflows

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.25+)
- Helm 3.8+
- Traefik ingress controller
- Cert-manager for SSL certificates
- ArgoCD (optional, for GitOps deployment)

### Basic Installation

```bash
# Add the repository
helm repo add itl-keycloak https://github.com/ITlusions/ITL.Keycloack.Tenants

# Install with default values
helm install my-keycloak-tenant itl-keycloak/itl.keycloak

# Install with custom tenant configuration
helm install my-keycloak-tenant itl-keycloak/itl.keycloak -f tenants/my-tenant.yaml
```

## Architecture

The chart deploys the following components:

```
┌─────────────────┐     ┌──────────────────┐    ┌─────────────────┐
│   Traefik       │     │   ModSecurity    │    │   Keycloak      │
│   Ingress       │───▶│   WAF Proxy      │───▶│   Instance      │
│                 │     │                  │    │                 │
└─────────────────┘     └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
                                                ┌─────────────────┐
                                                │   PostgreSQL    │
                                                │   Database      │
                                                └─────────────────┘
```

## Configuration

### Core Configuration Files

- [`values.yaml`](../values.yaml) - Default chart values
- [`tenants/`](../tenants/) - Tenant-specific configurations
- [`templates/`](../templates/) - Helm templates

### Detailed Configuration Guides

- [Keycloak Configuration](./keycloak-config.md)
- [ModSecurity Configuration](./modsecurity-config.md)
- [Database Configuration](./database-config.md)
- [Ingress and SSL Configuration](./ingress-ssl-config.md)

## Deployment

### ArgoCD Deployment (Recommended)

See [ArgoCD Deployment Guide](./argocd-deployment.md) for GitOps setup.

### Manual Helm Deployment

See [Manual Deployment Guide](./manual-deployment.md) for direct Helm installation.

## Security

### ModSecurity Web Application Firewall

The chart includes ModSecurity CRS (Core Rule Set) for web application protection:

- OWASP Top 10 protection
- Custom rule overrides
- Health check exclusions

### SSL/TLS Configuration

- Automatic certificate provisioning via cert-manager
- TLS 1.2+ enforcement
- Secure cipher suites

## Troubleshooting

Common issues and solutions:

- [ArgoCD Sync Errors](./troubleshooting/argocd-sync-errors.md)
- [ModSecurity Issues](./troubleshooting/modsecurity-issues.md)
- [Database Connection Problems](./troubleshooting/database-issues.md)
- [SSL Certificate Issues](./troubleshooting/ssl-issues.md)

## Maintainers

- **Niels Weistra** - [n.weistra@itlusions.nl](mailto:n.weistra@itlusions.nl)

## Support

For support, please contact the ITLusions team or create an issue in the GitHub repository.