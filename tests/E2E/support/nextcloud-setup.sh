#!/bin/sh
set -e

for app in admin_group_manager wordpress_login_backend; do
	mkdir -p "custom_apps/$app"
	curl -fsSL "https://github.com/LibreSign/$app/archive/refs/heads/main.tar.gz" | tar -xz --strip-components=1 -C "custom_apps/$app"
done

php occ app:install groupquota --force --keep-disabled
php occ app:enable wordpress_login_backend
php occ app:enable admin_group_manager --force
php occ app:enable groupquota --force
php occ config:system:set wordpress_dsn --value "mysql:host=mariadb;port=3306;dbname=wordpress;user=root;password=root"
php occ config:system:set auth.bruteforce.protection.enabled --value=false --type=boolean
php occ config:system:set ratelimit.protection.enabled --value=false --type=boolean
