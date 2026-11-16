#!/bin/sh
set -e

download_app() {
	mkdir -p "custom_apps/$1"
	curl -fsSL "https://github.com/LibreSign/$1/archive/$2.tar.gz" | tar -xz --strip-components=1 -C "custom_apps/$1"
}

download_app admin_group_manager 826b04a5364a03495da8bdfed8416eca1284a21b
download_app wordpress_login_backend eab143d586b2331329d406ef4460734499fb66c4

php occ app:install groupquota --force --keep-disabled
php occ app:enable wordpress_login_backend
php occ app:enable admin_group_manager --force
php occ app:enable groupquota --force
php occ config:system:set auth.bruteforce.protection.enabled --value=false --type=boolean
php occ config:system:set ratelimit.protection.enabled --value=false --type=boolean
