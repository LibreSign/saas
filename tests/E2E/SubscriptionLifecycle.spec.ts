import { expect, test } from '@playwright/test';

import { nextcloud } from './support/nextcloud';
import { aSubscriber, chooseThePlan, logInToTheStore, placeTheOrder, STORE_URL } from './support/store';
import { runScheduledSubscriptionAction, subscriptionStatus } from './support/wordpress';

test.describe( 'Keeping the plan over time', () => {
	test( 'an unpaid renewal suspends the workspace until the customer pays it', async ( { browser, page } ) => {
		const { customer, subscriptionId } = await aSubscriber( page, 'Joana' );

		runScheduledSubscriptionAction( 'woocommerce_scheduled_subscription_payment', subscriptionId );

		expect( subscriptionStatus( subscriptionId ) ).toBe( 'on-hold' );
		await nextcloud.expectAccountDisabled( browser, customer.email, customer.password );

		await logInToTheStore( page, customer.email, customer.password );
		await page.goto( `/account/view-subscription/${ subscriptionId }/` );
		await page.getByRole( 'link', { name: 'Pay', exact: true } ).click();
		await page.getByRole( 'button', { name: 'Renew subscription' } ).click();
		await expect( page ).toHaveURL( /\/checkout\/order-received\/\d+\//, { timeout: 90_000 } );

		expect( subscriptionStatus( subscriptionId ) ).toBe( 'active' );
		await nextcloud.expectToLogIn( browser, customer.email, customer.password );
	} );

	test( 'a customer who cancels loses the workspace and gets it back by signing up again', async ( { browser, page } ) => {
		const { customer, subscriptionId } = await aSubscriber( page, 'Karina' );

		await logInToTheStore( page, customer.email, customer.password );
		await page.goto( `/account/view-subscription/${ subscriptionId }/` );
		await page.getByRole( 'button', { name: 'Cancel', exact: true } ).click();
		await page.getByRole( 'link', { name: 'Yes, cancel subscription' } ).click();
		await expect( page.getByText( 'Your subscription has been cancelled.' ) ).toBeVisible();

		expect( subscriptionStatus( subscriptionId ) ).toBe( 'pending-cancel' );
		await nextcloud.expectAccountDisabled( browser, customer.email, customer.password );

		runScheduledSubscriptionAction( 'woocommerce_scheduled_subscription_end_of_prepaid_term', subscriptionId );

		expect( subscriptionStatus( subscriptionId ) ).toBe( 'cancelled' );
		await nextcloud.expectAccountDisabled( browser, customer.email, customer.password );

		await chooseThePlan( page, 'Basic', 'Monthly' );
		await page.goto( `${ STORE_URL }/checkout/` );
		await placeTheOrder( page );

		await nextcloud.expectToLogIn( browser, customer.email, customer.password );
		expect( await nextcloud.account( customer.email ) ).toMatchObject( { enabled: true, groups: [ customer.email ] } );
	} );
} );
