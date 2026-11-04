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

# The E2E stack uses direct HTTP between containers; NCDD uses a separate HTTPS proxy.
$wp option update nextcloud_api_host http://nextcloud
[ "$( $wp option get nextcloud_api_host )" = "http://nextcloud" ]
$wp option update nextcloud_api_login admin
$wp option update nextcloud_api_password admin
# Fail during environment setup rather than waiting for Playwright timeouts.
$wp eval '
	if ( ! function_exists( "agm_nextcloud_request" ) ) {
		WP_CLI::error( "The Nextcloud integration plugin is not active." );
	}
	$response = agm_nextcloud_request( "GET", "/ocs/v2.php/cloud/user?format=json" );
	if ( ! $response->succeeded() ) {
		WP_CLI::error( $response->failure_message() );
	}
	WP_CLI::success( "WordPress can authenticate against Nextcloud." );
'
$wp option update smtp_from noreply@example.com
$wp theme activate libresign
$wp plugin deactivate product-open-pricing-name-your-price-for-woocommerce
$wp wc hpos enable --ignore-plugin-compatibility
$wp rewrite structure '/%category%/%postname%/'
$wp eval-file /e2e/seed.php
$wp rewrite flush
