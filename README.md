# LibreSign

Document management and signature solution with full control over your data.

## LibreSisn SaaS

Orchestrates LibreSign provisioning with WordPress as client-facing layer for SaaS deployment.

## Quick Start

```bash
make up
make down
make help  # View all available commands
```

## Integration Flow

WordPress is the customer-facing commerce and account portal (plans, subscriptions, invoices, payments, and account reports).

### Component Roles

- [`Makefile`](./Makefile): orchestrates local development environment (start services, connect networks, setup and enable required Nextcloud apps).
- [`wordpress-docker`](https://github.com/LibreCodeCoop/wordpress-docker): storefront and customer account portal (checkout, subscriptions, invoices, billing).
- [`woocommerce-nextcloud-admin-group-manager`](https://github.com/LibreSign/woocommerce-nextcloud-admin-group-manager) (WordPress plugin): converts subscription/account events into integration calls.
- [`nextcloud-development`](https://github.com/LibreCodeCoop/nextcloud-docker-development): local Nextcloud runtime where integration apps are installed/enabled.
- [`admin_group_manager`](https://github.com/LibreSign/admin_group_manager) (Nextcloud app/API): receives integration calls and applies provisioning/access updates.
- [`wordpress_login_backend`](https://github.com/LibreSign/wordpress_login_backend) (Nextcloud app): allows authentication in Nextcloud using WordPress credentials.

### Developer Flow

```mermaid
sequenceDiagram
    actor Dev as Developer
    participant Make as make up
    participant WP as wordpress-docker
    participant NC as nextcloud-development

    Dev->>Make: make up
    Make->>WP: start services
    Make->>NC: start services
    Make->>NC: clone and enable admin_group_manager
    Make->>NC: clone and enable wordpress_login_backend
    Make->>NC: connect networks
    Make->>NC: provision admin user
```

### Customer Flow

```mermaid
sequenceDiagram
    actor User as Customer
    participant WP as WordPress (Store + Account)
    participant Plugin as woocommerce-nextcloud-admin-group-manager
    participant AGM as admin_group_manager (Nextcloud app/API)
    participant NC as Nextcloud portal
    participant WLB as wordpress_login_backend

    User->>WP: choose plan and checkout
    User->>WP: manage billing and invoices
    WP->>Plugin: subscription event
    Plugin->>AGM: provision/update access
    User->>NC: login with WordPress credentials
    NC->>WLB: validate credentials
```
