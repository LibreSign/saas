#!/bin/sh
set -e

download_app() {
	mkdir -p "custom_apps/$1"
	curl -fsSL "https://github.com/LibreSign/$1/archive/$2.tar.gz" | tar -xz --strip-components=1 -C "custom_apps/$1"
}

download_app admin_group_manager ae7e1f9b67071b3d4bdae9f9865099ed0368f812
download_app wordpress_login_backend 6837f710416f96c62176d7d2873fe28f9762189e

php occ app:install groupquota --force --keep-disabled
php occ app:enable wordpress_login_backend
php occ app:enable admin_group_manager --force
php occ app:enable groupquota --force
php occ config:system:set wordpress_dsn --value "mysql:host=mariadb;port=3306;dbname=wordpress;user=root;password=root"
php occ config:system:set auth.bruteforce.protection.enabled --value=false --type=boolean
php occ config:system:set ratelimit.protection.enabled --value=false --type=boolean
