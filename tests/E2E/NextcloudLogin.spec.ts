import { expect, test } from '@playwright/test';

import { nextcloud } from './support/nextcloud';
import { aSubscriber, logInAsAdmin, logInToTheStore, newCustomer } from './support/store';
import { wp } from './support/wordpress';

test.describe( 'Logging into Nextcloud with the store account', () => {
	test( 'a store account without a plan is refused', async ( { browser } ) => {
		const customer = newCustomer( 'Elisa' );
		wp( 'user', 'create', customer.email, customer.email, `--user_pass=${ customer.password }`, '--role=customer' );

		await nextcloud.expectWrongLoginOrPassword( browser, customer.email, customer.password );
		expect( await nextcloud.account( customer.email ) ).toBeNull();
	} );

	test( 'a subscriber with a wrong password is refused', async ( { browser, page } ) => {
		const { customer } = await aSubscriber( page, 'Fernanda' );

		await nextcloud.expectWrongLoginOrPassword( browser, customer.email, 'not-the-password' );
	} );

	test.fail( 'a password changed in the account details replaces the old one', { annotation: { type: 'issue', description: 'https://github.com/LibreSign/wordpress_login_backend/issues/22' } }, async ( { browser, page } ) => {
		const { customer } = await aSubscriber( page, 'Gustavo' );
		const newPassword = `${ customer.password }-changed`;

		await logInToTheStore( page, customer.email, customer.password );
		await page.goto( '/account/edit-account/' );
		await page.locator( '#password_current' ).fill( customer.password );
		await page.locator( '#password_1' ).fill( newPassword );
		await page.locator( '#password_2' ).fill( newPassword );
		await page.getByRole( 'button', { name: 'Save changes' } ).click();
		await expect( page.getByText( 'Account details changed successfully.' ) ).toBeVisible();

		await nextcloud.expectToLogIn( browser, customer.email, newPassword );
		await nextcloud.expectWrongLoginOrPassword( browser, customer.email, customer.password );
	} );

	test( 'an e-mail changed in the account details is copied to Nextcloud', async ( { browser, page } ) => {
		const { customer } = await aSubscriber( page, 'Heitor' );
		const newEmail = newCustomer( 'Heitor' ).email;

		await logInToTheStore( page, customer.email, customer.password );
		await page.goto( '/account/edit-account/' );
		await page.locator( '#account_email' ).fill( newEmail );
		await page.getByRole( 'button', { name: 'Save changes' } ).click();
		await expect( page.getByText( 'Account details changed successfully.' ) ).toBeVisible();

		expect( await nextcloud.account( customer.email ) ).toMatchObject( { email: newEmail } );
	} );

	test( 'a store account deleted by the admin is refused', async ( { browser, page } ) => {
		const { customer } = await aSubscriber( page, 'Iara' );
		await nextcloud.expectToLogIn( browser, customer.email, customer.password );

		await logInAsAdmin( page );
		await page.goto( `/wp-admin/users.php?s=${ encodeURIComponent( customer.email ) }` );
		const userRow = page.locator( '#the-list tr' ).filter( { hasText: customer.email } );
		await userRow.hover();
		page.once( 'dialog', ( dialog ) => dialog.accept() );
		await userRow.getByRole( 'link', { name: 'Delete', exact: true } ).click();
		await page.getByRole( 'radio', { name: 'Delete all content.' } ).check();
		await page.getByRole( 'button', { name: 'Confirm Deletion' } ).click();
		await expect( page.getByText( 'User deleted.' ) ).toBeVisible();

		await nextcloud.expectAccountDisabled( browser, customer.email, customer.password );
	} );
} );
