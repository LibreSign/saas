.PHONY: up down

# Variables
ROOT_DIR := $(shell pwd)
NEXTCLOUD_DIR := $(ROOT_DIR)/nextcloud-development
NEXTCLOUD_HTTP_PORT ?= 8082
NEXTCLOUD_BASE_URL := http://localhost:$(NEXTCLOUD_HTTP_PORT)
NEXTCLOUD_APPS_DIR := $(NEXTCLOUD_DIR)/volumes/nextcloud/apps-extra
LOCAL_UID := $(shell id -u)
LOCAL_GID := $(shell id -g)

# Docker Compose commands
NEXTCLOUD_COMPOSE := HTTP_PORT=$(NEXTCLOUD_HTTP_PORT) docker compose -f $(NEXTCLOUD_DIR)/docker-compose.yml
WORDPRESS_COMPOSE := docker compose -f $(ROOT_DIR)/docker-compose.override.yml
NEXTCLOUD_OCC := $(NEXTCLOUD_COMPOSE) exec -u www-data nextcloud php occ
WORDPRESS_CLI := $(WORDPRESS_COMPOSE) exec wordpress wp --allow-root

_help:
	@echo "LibreSign SaaS - Available commands:"
	@echo ""
	@echo "  make up    - Start all services (WordPress + Nextcloud)"
	@echo "  make down  - Stop all services"
	@echo ""
	@echo "Environment variables:"
	@echo "  NEXTCLOUD_HTTP_PORT              - Nextcloud port (default: 8082)"
	@echo "  NEXTCLOUD_ADMIN_USER             - Nextcloud admin username (default: admin)"
	@echo "  NEXTCLOUD_ADMIN_PASSWORD         - Nextcloud admin password (default: admin)"
	@echo "  WORDPRESS_LOCAL_USERS_PASSWORD   - WordPress users password (default: admin)"
	@echo "  WORDPRESS_LOCAL_RESET_ALL_USERS_PASSWORDS - Reset all passwords on startup (default: 1)"
	@echo ""

up: _start-services _wait-wordpress _wait-nextcloud _fix-nextcloud-apps-permissions _enable-wordpress-plugin _connect-networks _setup-apps _provision-user
	@echo "Environment up."

down:
	$(NEXTCLOUD_COMPOSE) down
	$(WORDPRESS_COMPOSE) down
	@echo "Environment down."

_start-services:
	@echo "Starting WordPress services..."
	@$(WORDPRESS_COMPOSE) up -d mariadb wordpress nginx
	@echo "Starting Nextcloud services..."
	@$(NEXTCLOUD_COMPOSE) up -d mysql redis nextcloud nginx

_wait-wordpress:
	@echo "Waiting for WordPress to be ready..."
	@attempt=0; \
	until $(WORDPRESS_CLI) core is-installed >/dev/null 2>&1; do \
		attempt=$$((attempt + 1)); \
		if [ $$attempt -ge 60 ]; then \
			echo "WordPress is not ready after 120s"; \
			exit 1; \
		fi; \
		sleep 2; \
	done

_wait-nextcloud:
	@echo "Waiting for Nextcloud to be ready..."
	@attempt=0; \
	until $(NEXTCLOUD_COMPOSE) exec -T nextcloud pgrep php-fpm >/dev/null 2>&1; do \
		attempt=$$((attempt + 1)); \
		if [ $$attempt -ge 120 ]; then \
			echo "Nextcloud is not ready for app operations after 240s"; \
			exit 1; \
		fi; \
		sleep 2; \
	done

_fix-nextcloud-apps-permissions:
	@echo "Fixing Nextcloud apps-extra permissions..."
	@$(NEXTCLOUD_COMPOSE) exec -u root nextcloud sh -lc 'mkdir -p /var/www/html/apps-extra && chown -R $(LOCAL_UID):$(LOCAL_GID) /var/www/html/apps-extra' >/dev/null

_enable-wordpress-plugin:
	@echo "Enabling WordPress plugin..."
	@$(WORDPRESS_CLI) plugin activate woocommerce-nextcloud-admin-group-manager >/dev/null || true

_setup-apps: _ensure-wordpress-app _ensure-nextcloud-app _enable-apps _set-wordpress-dsn

_ensure-wordpress-app:
	@echo "Setting up wordpress_login_backend app..."
	@if [ ! -d "$(NEXTCLOUD_APPS_DIR)/wordpress_login_backend/.git" ]; then \
		git clone https://github.com/LibreSign/wordpress_login_backend.git $(NEXTCLOUD_APPS_DIR)/wordpress_login_backend; \
	fi
	@git -C $(NEXTCLOUD_APPS_DIR)/wordpress_login_backend fetch origin main
	@git -C $(NEXTCLOUD_APPS_DIR)/wordpress_login_backend checkout main
	@git -C $(NEXTCLOUD_APPS_DIR)/wordpress_login_backend pull --ff-only origin main

_ensure-nextcloud-app:
	@echo "Setting up admin_group_manager app..."
	@if [ ! -d "$(NEXTCLOUD_APPS_DIR)/admin_group_manager/.git" ]; then \
		git clone https://github.com/LibreSign/admin_group_manager.git $(NEXTCLOUD_APPS_DIR)/admin_group_manager; \
	fi
	@git -C $(NEXTCLOUD_APPS_DIR)/admin_group_manager fetch origin main
	@git -C $(NEXTCLOUD_APPS_DIR)/admin_group_manager checkout main
	@git -C $(NEXTCLOUD_APPS_DIR)/admin_group_manager pull --ff-only origin main

_enable-apps:
	@echo "Enabling apps..."
	@$(NEXTCLOUD_OCC) app:enable wordpress_login_backend >/dev/null || true
	@$(NEXTCLOUD_OCC) app:enable admin_group_manager --force >/dev/null || true
	@$(NEXTCLOUD_OCC) app:enable groupquota --force >/dev/null || true

_set-wordpress-dsn:
	@$(NEXTCLOUD_OCC) config:system:set wordpress_dsn --value "mysql:host=mariadb;port=3306;dbname=wordpress;user=root;password=root" >/dev/null

_connect-networks:
	@echo "Connecting Docker networks..."
	@NEXTCLOUD_CONTAINER=$$($(NEXTCLOUD_COMPOSE) ps -q nextcloud); \
	WORDPRESS_CONTAINER=$$($(WORDPRESS_COMPOSE) ps -q mariadb); \
	WORDPRESS_NETWORK=$$(docker inspect -f '{{range $$k,$$v := .NetworkSettings.Networks}}{{println $$k}}{{end}}' $$WORDPRESS_CONTAINER | head -n1); \
	docker network connect $$WORDPRESS_NETWORK $$NEXTCLOUD_CONTAINER 2>/dev/null || true

_provision-user:
	@echo "Provisioning admin user..."
	@curl -sS -u admin:admin \
		-X POST "$(NEXTCLOUD_BASE_URL)/ocs/v2.php/apps/admin_group_manager/api/v1/admin-group" \
		-H "OCS-APIREQUEST: true" \
		-d "groupid=admlibrecode" \
		-d "email=adm@librecode.coop" \
		-d "displayname=Adm Librecode" >/dev/null || true
