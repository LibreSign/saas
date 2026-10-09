#!/bin/sh

set -eu

: "${NEXTCLOUD_COMPOSE:?Run this test with make test-integration}"
: "${WORDPRESS_COMPOSE:?Run this test with make test-integration}"

root_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"

nextcloud_compose() {
	$NEXTCLOUD_COMPOSE "$@"
}

wordpress_compose() {
	$WORDPRESS_COMPOSE "$@"
}

occ() {
	nextcloud_compose exec -T -u www-data nextcloud php occ "$@"
}

wp() {
	wordpress_compose exec -T wordpress wp --allow-root "$@"
}

fail() {
	echo "not ok - $1" >&2
	exit 1
}

pass() {
	echo "ok - $1"
}

assert_services_running() {
	stack="$1"
	shift
	running="$("${stack}_compose" ps --status running --services)" || fail "list the running $stack services"
	for service in "$@"; do
		echo "$running" | grep -qx "$service" || fail "$stack service $service is running"
	done
	pass "$stack services are running"
}

nextcloud_url() {
	nextcloud_compose exec -T nextcloud sh -c 'printf "%s://%s" "${NEXTCLOUD_PROTOCOL:?}" "${NEXTCLOUD_HOST:?}"'
}

assert_wordpress_uses_nextcloud_url() {
	expected="$(nextcloud_url)" || fail "read the Nextcloud URL configured by NCDD"
	actual="$(wp option get nextcloud_api_host)" || fail "read the Nextcloud URL configured in WordPress"
	[ "$actual" = "$expected" ] || fail "WordPress uses $expected for Nextcloud (got $actual)"
	pass "WordPress uses the Nextcloud URL configured by NCDD"
}

assert_wordpress_uses_its_own_services() {
	mailpit_ips="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$(wordpress_compose ps -q mailpit)")" || fail "inspect the WordPress mailpit"
	resolved="$(wordpress_compose exec -T wordpress getent hosts mailpit | awk '{print $1}')" || fail "resolve mailpit from WordPress"
	case " $mailpit_ips " in
		*" $resolved "*) pass "WordPress resolves mailpit to its own service" ;;
		*) fail "WordPress resolves mailpit to its own service (got $resolved, expected one of $mailpit_ips)" ;;
	esac
}

assert_wordpress_reaches_nextcloud() {
	wp eval '
		$response = wp_remote_get( rtrim( get_option( "nextcloud_api_host" ), "/" ) . "/status.php", array( "sslverify" => true ) );
		if ( is_wp_error( $response ) || 200 !== wp_remote_retrieve_response_code( $response ) ) {
			WP_CLI::error( is_wp_error( $response ) ? $response->get_error_message() : wp_remote_retrieve_body( $response ) );
		}
	' >/dev/null || fail "WordPress reaches Nextcloud with a verified TLS certificate"
	pass "WordPress reaches Nextcloud with a verified TLS certificate"
}

assert_authenticated_request() {
	wp eval '
		$response = agm_nextcloud_request( "GET", "/ocs/v2.php/cloud/user?format=json" );
		if ( ! $response->succeeded() ) {
			WP_CLI::error( $response->failure_message() );
		}
	' >/dev/null || fail "WordPress performs an authenticated Nextcloud API request"
	pass "WordPress performs an authenticated Nextcloud API request"
}

assert_integration_enabled() {
	enabled_apps="$(occ app:list --enabled)" || fail "list the enabled Nextcloud apps"
	for app in wordpress_login_backend admin_group_manager groupquota; do
		echo "$enabled_apps" | grep -q "^  - $app:" || fail "Nextcloud app $app is enabled"
	done
	wp plugin is-active woocommerce-nextcloud-admin-group-manager || fail "WordPress plugin woocommerce-nextcloud-admin-group-manager is active"
	occ group:info admlibrecode >/dev/null || fail "Nextcloud group admlibrecode is provisioned"
	pass "Integration apps, plugin and admin group are in place"
}

configuration_snapshot() {
	occ config:system:get trusted_domains &&
		occ config:system:get overwritehost &&
		occ config:system:get overwriteprotocol &&
		occ config:system:get wordpress_dsn &&
		wp option get nextcloud_api_host &&
		wp option get siteurl
}

assert_environment() {
	assert_services_running nextcloud database redis nextcloud nginx proxy-coordinator
	assert_services_running wordpress mariadb wordpress nginx mailpit
	assert_wordpress_uses_nextcloud_url
	assert_wordpress_uses_its_own_services
	assert_wordpress_reaches_nextcloud
	assert_authenticated_request
	assert_integration_enabled
}

assert_environment

before="$(configuration_snapshot)" || fail "read the configuration before running make up again"
make -C "$root_dir" --no-print-directory up wordpress nextcloud >/dev/null || fail "run make up again"
after="$(configuration_snapshot)" || fail "read the configuration after running make up again"
[ "$before" = "$after" ] || fail "Running make up again keeps the existing configuration"
pass "Running make up again keeps the existing configuration"

assert_environment
