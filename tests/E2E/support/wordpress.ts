import { execFileSync } from 'node:child_process';
import { join } from 'node:path';

const COMPOSE_FILE = join( __dirname, '..', 'docker-compose.yml' );

export function compose( ...args: string[] ): string {
	return execFileSync( 'docker', [ 'compose', '-f', COMPOSE_FILE, ...args ], { encoding: 'utf8' } ).trim();
}

export function wp( ...args: string[] ): string {
	return compose( 'exec', '-T', '-u', 'www-data', 'wordpress', 'wp', ...args );
}

export function wpEval( php: string ): string {
	return wp( 'eval', php );
}

export function runScheduledSubscriptionAction( hook: 'woocommerce_scheduled_subscription_payment' | 'woocommerce_scheduled_subscription_end_of_prepaid_term', subscriptionId: number ): void {
	wpEval( `do_action( '${ hook }', ${ subscriptionId } );` );
}

export function subscriptionStatus( subscriptionId: number ): string {
	return wpEval( `echo wcs_get_subscription( ${ subscriptionId } )->get_status();` );
}

export function orderStatus( orderId: number ): string {
	return wpEval( `echo wc_get_order( ${ orderId } )->get_status();` );
}

export function runTheScheduledNextcloudSyncRetry( orderId: number ): void {
	wpEval( `
		if ( ! as_next_scheduled_action( 'agm_retry_nextcloud_sync', array( 'order_id' => ${ orderId } ), 'nextcloud-admin-group-manager' ) ) {
			throw new RuntimeException( 'No Nextcloud sync retry is scheduled for order ${ orderId }' );
		}
		do_action( 'agm_retry_nextcloud_sync', ${ orderId } );
	` );
}
