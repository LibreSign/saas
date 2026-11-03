import { Browser, expect, Page } from '@playwright/test';

import { compose } from './wordpress';

const NEXTCLOUD_API = 'http://localhost:8892';

const NEXTCLOUD_URL = 'http://nextcloud';

export interface NextcloudAccount {
	enabled: boolean;
	email: string;
	displayname: string;
	groups: string[];
	subadmin: string[];
	quota: { quota: number };
}

export const nextcloud = {
	async account( id: string ): Promise< NextcloudAccount | null > {
		const response = await fetch( `${ NEXTCLOUD_API }/ocs/v2.php/cloud/users/${ encodeURIComponent( id ) }?format=json`, {
			headers: {
				Authorization: 'Basic ' + Buffer.from( 'admin:admin' ).toString( 'base64' ),
				'OCS-APIRequest': 'true',
			},
		} );
		if ( response.status === 404 ) {
			return null;
		}
		return ( ( await response.json() ) as { ocs: { data: NextcloudAccount } } ).ocs.data;
	},

	async logIn( browser: Browser, login: string, password: string ): Promise< Page > {
		const page = await ( await browser.newContext() ).newPage();
		await page.goto( `${ NEXTCLOUD_URL }/login` );
		await page.getByLabel( 'Account name or email' ).fill( login );
		await page.getByLabel( 'Password', { exact: true } ).fill( password );
		await page.getByRole( 'button', { name: 'Log in', exact: true } ).click();
		return page;
	},

	async expectToLogIn( browser: Browser, login: string, password: string ): Promise< void > {
		const page = await this.logIn( browser, login, password );
		await expect( page ).toHaveURL( /\/apps\/dashboard\// );
		await page.context().close();
	},

	async expectWrongLoginOrPassword( browser: Browser, login: string, password: string ): Promise< void > {
		const page = await this.logIn( browser, login, password );
		await expect( page.getByText( 'Wrong login or password.' ) ).toBeVisible();
		await page.context().close();
	},

	async expectAccountDisabled( browser: Browser, login: string, password: string ): Promise< void > {
		const page = await this.logIn( browser, login, password );
		await expect( page.getByText( 'This account is disabled' ) ).toBeVisible();
		await page.context().close();
	},

	stop(): void {
		compose( 'stop', 'nextcloud' );
	},

	start(): void {
		compose( 'up', '-d', '--wait', 'nextcloud' );
	},
};
