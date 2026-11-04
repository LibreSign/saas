import { expect } from '@playwright/test';

const MAILPIT_API = 'http://localhost:8893/api/v1';

type Message = { ID: string; Subject: string };

export async function mailTo( address: string, subject: string ): Promise< string > {
	let id = '';
	await expect( async () => {
		const response = await fetch( `${ MAILPIT_API }/search?query=${ encodeURIComponent( `to:"${ address }" subject:"${ subject }"` ) }` );
		const { messages } = ( await response.json() ) as { messages: Message[] };
		expect( messages ).not.toHaveLength( 0 );
		id = messages[ 0 ].ID;
	} ).toPass( { timeout: 30_000 } );

	const message = await fetch( `${ MAILPIT_API }/message/${ id }` );
	return ( ( await message.json() ) as { Text: string } ).Text;
}
