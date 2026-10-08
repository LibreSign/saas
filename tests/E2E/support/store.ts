import { randomUUID } from 'node:crypto';

import { expect, Page } from '@playwright/test';

import { mailTo } from './mailpit';

export const STORE_URL = 'http://localhost:8891';

export interface Customer {
	email: string;
	firstName: string;
	lastName: string;
	password: string;
}

export function newCustomer( firstName: string ): Customer {
	return {
		email: `${ firstName.toLowerCase() }-${ randomUUID().slice( 0, 8 ) }@example.com`,
		firstName,
		lastName: 'Silva',
		password: `${ firstName }-Password-${ randomUUID().slice( 0, 8 ) }`,
	};
}

export async function chooseThePlan( page: Page, plan: string, term: 'Monthly' | 'Yearly' ): Promise< void > {
	await page.goto( `${ STORE_URL }/store/` );
	await page.getByRole( 'link', { name: plan, exact: true } ).click();
	const termSelect = page.locator( 'select[name="attribute_term-length"]' );
	if ( ( await termSelect.inputValue() ) !== term.toLowerCase() ) {
		await page.locator( '.cfvsw-swatches-option', { hasText: term } ).click();
	}
	await expect( termSelect ).toHaveValue( term.toLowerCase() );
	await page.getByRole( 'button', { name: 'Sign up now' } ).click();
	await expect( page.getByText( `“${ plan }” has been added to your cart.` ) ).toBeVisible();
}

async function fillTheBillingDetails( page: Page, customer: Customer ): Promise< void > {
	await page.getByLabel( 'First name' ).fill( customer.firstName );
	await page.getByLabel( 'Last name' ).fill( customer.lastName );
	await page.getByLabel( 'Street address' ).fill( 'Rua da Assembleia, 10' );
	await page.getByLabel( 'Town / City' ).fill( 'Rio de Janeiro' );
	await page.getByLabel( 'Postcode / ZIP' ).fill( '20011-000' );
	await page.getByLabel( 'CPF or CNPJ' ).fill( '111.444.777-35' );
}

export async function agreeToTheTerms( page: Page ): Promise< void > {
	await page.getByRole( 'checkbox', { name: /^I agree to the terms and privacy policy/ } ).check();
}

export async function placeTheOrder( page: Page ): Promise< number > {
	await agreeToTheTerms( page );
	await page.getByRole( 'button', { name: 'Sign up now' } ).click();
	await expect( page ).toHaveURL( /\/checkout\/order-received\/\d+\//, { timeout: 90_000 } );
	return Number( page.url().match( /order-received\/(\d+)\// )![ 1 ] );
}

export async function signUp( page: Page, customer: Customer, plan: string, term: 'Monthly' | 'Yearly' ): Promise< number > {
	await chooseThePlan( page, plan, term );
	await page.goto( `${ STORE_URL }/checkout/` );
	await page.getByLabel( 'Email address' ).fill( customer.email );
	await fillTheBillingDetails( page, customer );
	return placeTheOrder( page );
}

export async function subscriptionOf( page: Page ): Promise< number > {
	const name = await page.getByRole( 'link', { name: /^View subscription number \d+$/ } ).first().getAttribute( 'aria-label' );
	return Number( name!.match( /\d+/ )![ 0 ] );
}

export async function setThePasswordFromTheWelcomeMail( page: Page, customer: Customer ): Promise< void > {
	const text = await mailTo( customer.email, 'Your LibreSign account has been created!' );
	await page.goto( text.match( /\( (http\S+action=newaccount\S+) \)/ )![ 1 ] );
	await page.locator( '#password_1' ).fill( customer.password );
	await page.locator( '#password_2' ).fill( customer.password );
	await page.getByRole( 'button', { name: 'Save' } ).click();
	await expect( page.getByRole( 'alert' ).first() ).toContainText( 'Your password has been reset successfully.' );
}

export async function logInToTheStore( page: Page, login: string, password: string ): Promise< void > {
	await page.context().clearCookies();
	await page.goto( `${ STORE_URL }/account/` );
	await page.getByLabel( 'Username or email address' ).fill( login );
	await page.locator( '#password' ).fill( password );
	await page.getByRole( 'button', { name: 'Log in' } ).click();
	await expect( page.getByRole( 'link', { name: 'Log out' } ).first() ).toBeVisible();
}

export async function logInAsAdmin( page: Page ): Promise< void > {
	await page.context().clearCookies();
	await page.goto( `${ STORE_URL }/wp-login.php` );
	await page.getByLabel( 'Username or Email Address' ).fill( 'admin' );
	await page.getByLabel( 'Password', { exact: true } ).fill( 'admin' );
	await page.getByRole( 'button', { name: 'Log In' } ).click();
	await expect( page ).toHaveURL( /wp-admin/ );
}

export async function aSubscriber( page: Page, firstName: string ): Promise< { customer: Customer; subscriptionId: number } > {
	const customer = newCustomer( firstName );
	await signUp( page, customer, 'Basic', 'Monthly' );
	const subscriptionId = await subscriptionOf( page );
	await setThePasswordFromTheWelcomeMail( page, customer );
	return { customer, subscriptionId };
}

export async function plansInTheStore( page: Page ): Promise< string[] > {
	await page.goto( `${ STORE_URL }/store/` );
	return page.locator( '.wp-block-post-title' ).allInnerTexts();
}
