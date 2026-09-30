import { expect, test } from '@playwright/test';

import { mailTo } from './support/mailpit';
import { nextcloud } from './support/nextcloud';
import { logInToTheStore, newCustomer, setThePasswordFromTheWelcomeMail, signUp, subscriptionOf } from './support/store';
import { orderStatus, runTheScheduledNextcloudSyncRetry, subscriptionStatus } from './support/wordpress';

const GIGABYTE = 1024 ** 3;

const plans = [
	{ plan: 'Basic', term: 'Monthly', storage: 2 },
	{ plan: 'Professional', term: 'Yearly', storage: 120 },
] as const;

test.describe( 'Signing up for a plan', () => {
	for ( const { plan, term, storage } of plans ) {
		test( `a visitor who signs up for ${ plan } ${ term.toLowerCase() } gets a Nextcloud workspace with ${ storage } GB`, async ( { page } ) => {
			const customer = newCustomer( 'Ana' );

			await signUp( page, customer, plan, term );

			await expect( page.getByRole( 'heading', { name: 'Order completed' } ) ).toBeVisible();
			expect( subscriptionStatus( await subscriptionOf( page ) ) ).toBe( 'active' );

			const workspace = await nextcloud.account( customer.email );
			expect( workspace ).toMatchObject( {
				enabled: true,
				email: customer.email,
				displayname: `${ customer.firstName } ${ customer.lastName }`,
				groups: [ customer.email ],
				subadmin: [ customer.email ],
				quota: { quota: storage * GIGABYTE },
			} );
		} );
	}

	test( 'the customer sets a password from the welcome mail and reaches Nextcloud from the account page', async ( { page } ) => {
		const customer = newCustomer( 'Bruno' );
		await signUp( page, customer, 'Basic', 'Monthly' );

		await setThePasswordFromTheWelcomeMail( page, customer );
		await logInToTheStore( page, customer.email, customer.password );
		const nextcloudTab = page.waitForEvent( 'popup' );
		await page.getByRole( 'link', { name: 'Ir para o sistema de assinaturas' } ).click();
		const nextcloudPage = await nextcloudTab;
		await nextcloudPage.getByLabel( 'Account name or email' ).fill( customer.email );
		await nextcloudPage.getByLabel( 'Password', { exact: true } ).fill( customer.password );
		await nextcloudPage.getByRole( 'button', { name: 'Log in', exact: true } ).click();

		await expect( nextcloudPage ).toHaveURL( /\/apps\/dashboard\// );
	} );

	test( 'the store and the customer are notified by mail', async ( { page } ) => {
		const customer = newCustomer( 'Clara' );

		const orderId = await signUp( page, customer, 'Basic', 'Monthly' );

		await mailTo( customer.email, 'order has been received' );
		await mailTo( 'admin@example.com', `#${ orderId }` );
	} );

	test.fail( 'a workspace ordered while Nextcloud is down is created by the scheduled retry', { annotation: { type: 'issue', description: 'https://github.com/LibreSign/woocommerce-nextcloud-admin-group-manager/issues/34' } }, async ( { page } ) => {
		const customer = newCustomer( 'Diego' );

		nextcloud.stop();
		let orderId: number;
		try {
			orderId = await signUp( page, customer, 'Basic', 'Monthly' );
		} finally {
			nextcloud.start();
		}

		expect( await nextcloud.account( customer.email ) ).toBeNull();
		expect( orderStatus( orderId ) ).toBe( 'processing' );

		runTheScheduledNextcloudSyncRetry( orderId );

		expect( await nextcloud.account( customer.email ) ).toMatchObject( { enabled: true, quota: { quota: 2 * GIGABYTE } } );
		expect( orderStatus( orderId ) ).toBe( 'completed' );
	} );
} );
