.PHONY: up down

# Variables
ROOT_DIR := $(shell pwd)
NEXTCLOUD_DIR := $(ROOT_DIR)/nextcloud-development
WORDPRESS_DIR := $(ROOT_DIR)/wordpress-docker
NEXTCLOUD_HTTP_PORT ?= 8080
NEXTCLOUD_BASE_URL := http://localhost:$(NEXTCLOUD_HTTP_PORT)
NEXTCLOUD_APPS_DIR := $(NEXTCLOUD_DIR)/volumes/nextcloud/apps-extra

# Docker Compose commands
NEXTCLOUD_COMPOSE := HTTP_PORT=$(NEXTCLOUD_HTTP_PORT) docker compose -f $(NEXTCLOUD_DIR)/docker-compose.yml
WORDPRESS_COMPOSE := docker compose -f $(WORDPRESS_DIR)/docker-compose.yml -f $(WORDPRESS_DIR)/docker-compose.override.yml
NEXTCLOUD_OCC := $(NEXTCLOUD_COMPOSE) exec -u www-data nextcloud php occ
WORDPRESS_CLI := $(WORDPRESS_COMPOSE) exec wordpress wp --allow-root

_help:
	@echo "LibreSign SaaS - Available commands:"
	@echo ""
	@echo "  make up    - Start all services (WordPress + Nextcloud)"
	@echo "  make down  - Stop all services"
	@echo ""
	@echo "Environment variables:"
	@echo "  NEXTCLOUD_HTTP_PORT  - Nextcloud port (default: 8080)"
	@echo ""

up: _connect-networks _setup-apps _provision-user
	@echo "Environment up."

down:
	$(NEXTCLOUD_COMPOSE) down
	$(WORDPRESS_COMPOSE) down
	@echo "Environment down."

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
