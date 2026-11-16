<?php

$response = agm_nextcloud_request(
	'POST',
	'/ocs/v2.php/apps/admin_group_manager/api/v1/admin-group?format=json',
	array(
		'timeout' => 30,
		'body'    => array(
			'groupid'     => 'admlibrecode',
			'email'       => 'adm@librecode.coop',
			'displayname' => 'Adm Librecode',
		),
	)
);

if ( ! $response->succeeded() ) {
	WP_CLI::error( 'Could not provision the admin group in Nextcloud: ' . $response->failure_message() );
}

WP_CLI::success( 'Admin group provisioned in Nextcloud.' );
