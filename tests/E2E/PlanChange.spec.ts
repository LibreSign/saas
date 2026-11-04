import { expect, test } from '@playwright/test';

import { nextcloud } from './support/nextcloud';
import { agreeToTheTerms, aSubscriber, logInToTheStore, placeTheOrder, plansInTheStore, STORE_URL } from './support/store';
import { subscriptionStatus } from './support/wordpress';

const GIGABYTE = 1024 ** 3;

test.describe( 'Changing plan', () => {
	test( 'a visitor sees every plan, a Basic subscriber only Basic and its upgrade', async ( { page } ) => {
		expect( ( await plansInTheStore( page ) ).sort() ).toEqual( [ 'Basic', 'Enterprise', 'Professional' ] );

		const { customer, subscriptionId } = await aSubscriber( page, 'Marta' );
		await logInToTheStore( page, customer.email, customer.password );

		expect( ( await plansInTheStore( page ) ).sort() ).toEqual( [ 'Basic', 'Enterprise' ] );

		await page.goto( `${ STORE_URL }/account/view-subscription/${ subscriptionId }/` );
		await page.getByRole( 'link', { name: 'Upgrade' } ).click();
		await expect( page.getByText( 'Choose a new subscription.' ) ).toBeVisible();
		await expect( page.getByRole( 'link', { name: 'Enterprise', exact: true } ) ).toBeVisible();
		await expect( page.getByRole( 'link', { name: 'Basic', exact: true } ) ).toBeVisible();
		await expect( page.getByRole( 'link', { name: 'Professional', exact: true } ) ).toHaveCount( 0 );
	} );

	test( 'upgrading from Basic to Enterprise raises the workspace storage to 800 GB', async ( { browser, page } ) => {
		const { customer, subscriptionId } = await aSubscriber( page, 'Nilo' );
		await logInToTheStore( page, customer.email, customer.password );

		await page.goto( `${ STORE_URL }/account/view-subscription/${ subscriptionId }/` );
		await page.getByRole( 'link', { name: 'Upgrade' } ).click();
		await page.getByRole( 'link', { name: 'Enterprise', exact: true } ).click();
		await page.locator( '.cfvsw-swatches-option', { hasText: 'Monthly' } ).click();
		await page.getByRole( 'button', { name: 'Switch subscription' } ).click();
		await page.goto( `${ STORE_URL }/checkout/` );
		await agreeToTheTerms( page );
		await page.getByRole( 'button', { name: 'Switch subscription' } ).click();
		await expect( page ).toHaveURL( /\/checkout\/order-received\/\d+\//, { timeout: 90_000 } );

		expect( subscriptionStatus( subscriptionId ) ).toBe( 'active' );
		expect( await nextcloud.account( customer.email ) ).toMatchObject( { enabled: true, quota: { quota: 800 * GIGABYTE } } );
		await nextcloud.expectToLogIn( browser, customer.email, customer.password );
	} );
} );
