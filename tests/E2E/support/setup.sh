#!/bin/sh
set -e

compose="docker compose -f $(dirname "$0")/../docker-compose.yml"
wp="$compose exec -T -u www-data wordpress wp"

$compose up -d --wait

if ! $wp core is-installed 2>/dev/null; then
	$wp core install --url=http://localhost:8891 --title=LibreSign --admin_user=admin --admin_password=admin --admin_email=admin@example.com --skip-email
	$wp core update --version=7.0.4
	$wp core update-db
	$compose restart wordpress
	$compose up -d --wait wordpress
fi

$wp option update nextcloud_api_login admin
$wp option update nextcloud_api_password admin
$wp option update smtp_from noreply@example.com
$wp theme activate libresign
$wp plugin deactivate product-open-pricing-name-your-price-for-woocommerce
$wp wc hpos enable --ignore-plugin-compatibility
$wp rewrite structure '/%category%/%postname%/'
$wp eval-file /e2e/seed.php
$wp rewrite flush

wordpress_login_password=$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')
$compose exec -T mariadb mariadb -uroot -proot <<SQL
CREATE USER IF NOT EXISTS 'wordpress_login'@'%' IDENTIFIED BY '$wordpress_login_password';
ALTER USER 'wordpress_login'@'%' IDENTIFIED BY '$wordpress_login_password';
GRANT SELECT ON wordpress.wp_users TO 'wordpress_login'@'%';
GRANT SELECT ON wordpress.wp_wc_orders TO 'wordpress_login'@'%';
GRANT UPDATE (user_pass) ON wordpress.wp_users TO 'wordpress_login'@'%';
SQL
$compose exec -T -u www-data nextcloud php occ config:system:set wordpress_dsn --value "mysql:host=mariadb;port=3306;dbname=wordpress;user=wordpress_login;password=$wordpress_login_password"
