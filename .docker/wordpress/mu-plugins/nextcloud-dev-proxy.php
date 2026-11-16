<?php

const LIBRECODE_DEV_PROXY_CA = '/etc/librecode-dev-proxy-certs/nginx-proxy-ca.crt';

function librecode_dev_proxy_nextcloud_host( string $url ): ?string {
	$nextcloud_host = wp_parse_url( (string) get_option( 'nextcloud_api_host' ), PHP_URL_HOST );
	if ( ! $nextcloud_host || wp_parse_url( $url, PHP_URL_HOST ) !== $nextcloud_host ) {
		return null;
	}

	return $nextcloud_host;
}

add_filter(
	'http_request_args',
	static function ( array $args, string $url ): array {
		if ( ! librecode_dev_proxy_nextcloud_host( $url ) ) {
			return $args;
		}

		if ( is_readable( LIBRECODE_DEV_PROXY_CA ) ) {
			$args['sslcertificates'] = LIBRECODE_DEV_PROXY_CA;
		} else {
			error_log( 'The NCDD shared proxy CA is not available at ' . LIBRECODE_DEV_PROXY_CA . '.' );
		}

		return $args;
	},
	10,
	2
);

add_action(
	'http_api_curl',
	static function ( $handle, array $parsed_args, string $url ): void {
		$nextcloud_host = librecode_dev_proxy_nextcloud_host( $url );
		if ( ! $nextcloud_host ) {
			return;
		}

		// libcurl resolves *.localhost to the loopback (RFC 6761) and skips Docker DNS, where the shared proxy alias lives.
		$proxy_ip = gethostbyname( $nextcloud_host );
		if ( $proxy_ip === $nextcloud_host ) {
			error_log( "The NCDD shared proxy alias {$nextcloud_host} does not resolve on the WordPress network." );
			return;
		}

		$port = wp_parse_url( $url, PHP_URL_PORT ) ?? ( wp_parse_url( $url, PHP_URL_SCHEME ) === 'http' ? 80 : 443 );
		curl_setopt( $handle, CURLOPT_RESOLVE, array( "{$nextcloud_host}:{$port}:{$proxy_ip}" ) );
	},
	10,
	3
);
