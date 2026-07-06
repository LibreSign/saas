.PHONY: up down help _help site wordpress nextcloud _up-site _up-wordpress _up-nextcloud _up-integration

-include .env
export

# Variables
ROOT_DIR := $(shell pwd)
NEXTCLOUD_DIR := $(ROOT_DIR)/nextcloud-development
WORDPRESS_DIR := $(ROOT_DIR)/wordpress-docker
SITE_DIR := $(ROOT_DIR)/site
SITE_HTTP_PORT ?= 8081
SITE_BROWSERSYNC_PORT ?= 3000
SITE_SERVER_MODE ?= build
NEXTCLOUD_HTTP_PORT ?= 8082
SITE_BASE_URL := http://localhost:$(SITE_HTTP_PORT)
NEXTCLOUD_BASE_URL := http://localhost:$(NEXTCLOUD_HTTP_PORT)
NEXTCLOUD_APPS_DIR := $(NEXTCLOUD_DIR)/volumes/nextcloud/apps-extra
LOCAL_UID := $(shell id -u)
LOCAL_GID := $(shell id -g)
WORDPRESS_SITE_URL ?= http://localhost
WORDPRESS_SITE_TITLE ?= LibreSign SaaS
WORDPRESS_ADMIN_USER ?= admin
WORDPRESS_ADMIN_PASSWORD ?= admin
WORDPRESS_ADMIN_EMAIL ?= admin@example.com
WORDPRESS_WEBHOOK_BASE_URL ?= http://host.docker.internal
LIBRESIGN_PUBLISH_HEADER_FRAGMENTS ?= true
LIBRESIGN_HEADER_WEBHOOK_URL ?= $(WORDPRESS_WEBHOOK_BASE_URL)/wp-json/libresign/v1/header-fragment
LIBRESIGN_HEADER_WEBHOOK_SECRET ?= change-me-header
LIBRESIGN_HEADER_WEBHOOK_ALLOWED_IPS ?=
LIBRESIGN_PUBLISH_FOOTER_FRAGMENTS ?= true
LIBRESIGN_FOOTER_WEBHOOK_URL ?= $(WORDPRESS_WEBHOOK_BASE_URL)/wp-json/libresign/v1/footer-fragment
LIBRESIGN_FOOTER_WEBHOOK_SECRET ?= change-me-footer
LIBRESIGN_FOOTER_WEBHOOK_ALLOWED_IPS ?=
COMPONENT_TARGETS := site wordpress nextcloud
SELECTED_COMPONENTS := $(filter $(COMPONENT_TARGETS),$(MAKECMDGOALS))
UP_COMPONENTS := $(if $(SELECTED_COMPONENTS),$(SELECTED_COMPONENTS),$(COMPONENT_TARGETS))

# Docker Compose commands
NEXTCLOUD_COMPOSE := HTTP_PORT=$(NEXTCLOUD_HTTP_PORT) docker compose -f $(NEXTCLOUD_DIR)/docker-compose.yml
WORDPRESS_COMPOSE := docker compose -f $(WORDPRESS_DIR)/docker-compose.yml -f $(ROOT_DIR)/docker-compose.override.yml
SITE_COMPOSE := UID=$(LOCAL_UID) GID=$(LOCAL_GID) HTTP_PORT=$(SITE_HTTP_PORT) HTTP_PORT_BROWSERSYNC=$(SITE_BROWSERSYNC_PORT) SERVER_MODE=$(SITE_SERVER_MODE) URL_SITE=$(SITE_BASE_URL) LIBRESIGN_PUBLISH_HEADER_FRAGMENTS=$(LIBRESIGN_PUBLISH_HEADER_FRAGMENTS) LIBRESIGN_HEADER_WEBHOOK_URL=$(LIBRESIGN_HEADER_WEBHOOK_URL) LIBRESIGN_HEADER_WEBHOOK_SECRET=$(LIBRESIGN_HEADER_WEBHOOK_SECRET) LIBRESIGN_PUBLISH_FOOTER_FRAGMENTS=$(LIBRESIGN_PUBLISH_FOOTER_FRAGMENTS) LIBRESIGN_FOOTER_WEBHOOK_URL=$(LIBRESIGN_FOOTER_WEBHOOK_URL) LIBRESIGN_FOOTER_WEBHOOK_SECRET=$(LIBRESIGN_FOOTER_WEBHOOK_SECRET) docker compose -f $(SITE_DIR)/docker-compose.yml
NEXTCLOUD_OCC := $(NEXTCLOUD_COMPOSE) exec -u www-data nextcloud php occ
WORDPRESS_CLI := $(WORDPRESS_COMPOSE) exec wordpress wp --allow-root

_help:
	@echo "LibreSign SaaS - Available commands:"
	@echo ""
	@echo "  make up                        - Refresh images and start all services"
	@echo "  make up site                   - Start only the static site stack"
	@echo "  make up wordpress              - Start only the WordPress stack"
	@echo "  make up nextcloud              - Start only the Nextcloud stack"
	@echo "  make up wordpress nextcloud    - Start only the selected stacks"
	@echo "  make down  - Stop all services"
	@echo ""
	@echo "Environment variables:"
	@echo "  SITE_HTTP_PORT                   - Static site port (default: 8081)"
	@echo "  SITE_BROWSERSYNC_PORT            - Static site HMR port (default: 3000)"
	@echo "  SITE_SERVER_MODE                 - Static site container mode for make up (default: build)"
	@echo "  NEXTCLOUD_HTTP_PORT              - Nextcloud port (default: 8082)"
	@echo "  NEXTCLOUD_ADMIN_USER             - Nextcloud admin username (default: admin)"
	@echo "  NEXTCLOUD_ADMIN_PASSWORD         - Nextcloud admin password (default: admin)"
	@echo "  WORDPRESS_SITE_URL               - WordPress site URL for first install (default: http://localhost)"
	@echo "  WORDPRESS_ADMIN_USER             - WordPress admin username for first install (default: admin)"
	@echo "  WORDPRESS_ADMIN_PASSWORD         - WordPress admin password for first install (default: admin)"
	@echo "  WORDPRESS_ADMIN_EMAIL            - WordPress admin email for first install (default: admin@example.com)"
	@echo "  WORDPRESS_WEBHOOK_BASE_URL       - Hostname used by the static site container to reach WordPress webhooks (default: http://host.docker.internal)"
	@echo "  LIBRESIGN_PUBLISH_HEADER_FRAGMENTS - Publish shared header artifacts after site build (default: true)"
	@echo "  LIBRESIGN_HEADER_WEBHOOK_URL     - Target WordPress header webhook URL"
	@echo "  LIBRESIGN_HEADER_WEBHOOK_SECRET  - Shared secret for header artifact publishing"
	@echo "  LIBRESIGN_PUBLISH_FOOTER_FRAGMENTS - Publish shared footer artifacts after site build (default: true)"
	@echo "  LIBRESIGN_FOOTER_WEBHOOK_URL     - Target WordPress footer webhook URL"
	@echo "  LIBRESIGN_FOOTER_WEBHOOK_SECRET  - Shared secret for footer artifact publishing"
	@echo "  WORDPRESS_LOCAL_USERS_PASSWORD   - WordPress users password (default: admin)"
	@echo "  WORDPRESS_LOCAL_RESET_ALL_USERS_PASSWORDS - Reset all passwords on startup (default: 1)"
	@echo ""

help: _help

up:
	@for component in $(UP_COMPONENTS); do \
		$(MAKE) --no-print-directory _up-$$component; \
	done
	@if [ -n "$(filter wordpress,$(UP_COMPONENTS))" ] && [ -n "$(filter nextcloud,$(UP_COMPONENTS))" ]; then \
		$(MAKE) --no-print-directory _up-integration; \
	fi
	@echo "Environment up ($(UP_COMPONENTS))."

site wordpress nextcloud:
	@:

down:
	$(SITE_COMPOSE) down
	$(NEXTCLOUD_COMPOSE) down
	$(WORDPRESS_COMPOSE) down
	@echo "Environment down."

_up-site: _prepare-site-output-dir _refresh-site-images _start-site

_up-wordpress: _refresh-wordpress-images _start-wordpress _install-wordpress _wait-wordpress _enable-wordpress-plugin

_up-nextcloud: _refresh-nextcloud-images _start-nextcloud _wait-nextcloud _fix-nextcloud-apps-permissions

_up-integration: _connect-networks _setup-apps _provision-user

_prepare-site-output-dir:
	@echo "Preparing site output directory..."
	@rm -rf $(SITE_DIR)/build_local
	@mkdir -p $(SITE_DIR)/build_local
	@chmod 775 $(SITE_DIR)/build_local


_refresh-site-images:
	@echo "Refreshing site images..."
	@$(SITE_COMPOSE) pull php web

_refresh-wordpress-images:
	@echo "Refreshing WordPress images..."
	@$(WORDPRESS_COMPOSE) pull --ignore-buildable wordpress nginx
	@echo "Rebuilding WordPress buildable services..."
	@$(WORDPRESS_COMPOSE) build mariadb

_refresh-nextcloud-images:
	@echo "Refreshing Nextcloud images..."
	@$(NEXTCLOUD_COMPOSE) pull mysql redis nextcloud nginx

_start-site:
	@echo "Starting site services..."
	@$(SITE_COMPOSE) up -d --force-recreate php
	@attempt=0; \
	until [ -f "$(SITE_DIR)/build_local/index.html" ]; do \
		attempt=$$((attempt + 1)); \
		if [ $$attempt -ge 60 ]; then \
			echo "Static site build did not produce build_local/index.html after 120s"; \
			exit 1; \
		fi; \
		sleep 2; \
	done
	@$(SITE_COMPOSE) up -d --force-recreate web

_start-wordpress:
	@echo "Starting WordPress services..."
	@$(WORDPRESS_COMPOSE) up -d mariadb wordpress nginx

_start-nextcloud:
	@echo "Starting Nextcloud services..."
	@$(NEXTCLOUD_COMPOSE) up -d mysql redis nextcloud nginx

_install-wordpress:
	@echo "Ensuring WordPress core is installed..."
	@attempt=0; \
	while true; do \
		output=$$($(WORDPRESS_CLI) option get siteurl 2>&1); status=$$?; \
		if [ $$status -eq 0 ]; then \
			echo "WordPress already installed."; \
			break; \
		fi; \
		if echo "$$output" | grep -qi "not installed"; then \
			echo "WordPress not installed; running core install..."; \
			if ! $(WORDPRESS_CLI) core install \
				--url="$(WORDPRESS_SITE_URL)" \
				--title="$(WORDPRESS_SITE_TITLE)" \
				--admin_user="$(WORDPRESS_ADMIN_USER)" \
				--admin_password="$(WORDPRESS_ADMIN_PASSWORD)" \
				--admin_email="$(WORDPRESS_ADMIN_EMAIL)" \
				--skip-email; then \
				echo "WordPress core install failed."; \
				exit 1; \
			fi; \
			echo "Restarting WordPress container to install plugins and themes..."; \
			$(WORDPRESS_COMPOSE) restart wordpress >/dev/null; \
			break; \
		fi; \
		attempt=$$((attempt + 1)); \
		if [ $$attempt -ge 60 ]; then \
			echo "WordPress CLI/database not reachable after 120s"; \
			echo "$$output"; \
			exit 1; \
		fi; \
		sleep 2; \
	done

_wait-wordpress:
	@echo "Waiting for WordPress to be ready..."
	@attempt=0; \
	until output=$$($(WORDPRESS_CLI) option get siteurl 2>&1); do \
		attempt=$$((attempt + 1)); \
		if [ $$attempt -ge 60 ]; then \
			echo "WordPress is not ready after 120s"; \
			echo "$$output"; \
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
