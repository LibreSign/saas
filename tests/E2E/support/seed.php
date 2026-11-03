<?php

if ( get_page_by_path( 'upgrade-subscription', OBJECT, 'product' ) ) {
	return;
}

$options = array(
	'blogname'                                          => 'LibreSign',
	'timezone_string'                                   => 'America/Sao_Paulo',
	'users_can_register'                                => 0,
	'woocommerce_coming_soon'                           => 'no',
	'woocommerce_currency'                              => 'USD',
	'woocommerce_currency_pos'                          => 'left_space',
	'woocommerce_price_decimal_sep'                     => ',',
	'woocommerce_price_thousand_sep'                    => '.',
	'woocommerce_price_num_decimals'                    => 2,
	'woocommerce_default_country'                       => 'BR:RJ',
	'woocommerce_calc_taxes'                            => 'no',
	'woocommerce_enable_guest_checkout'                 => 'yes',
	'woocommerce_enable_checkout_login_reminder'        => 'no',
	'woocommerce_enable_signup_and_login_from_checkout' => 'no',
	'woocommerce_enable_myaccount_registration'         => 'no',
	'woocommerce_registration_generate_username'        => 'yes',
	'woocommerce_registration_generate_password'        => 'yes',
	'woocommerce_checkout_company_field'                => 'hidden',
	'woocommerce_checkout_address_2_field'              => 'optional',
	'woocommerce_checkout_phone_field'                  => 'optional',
	'woocommerce_email_from_name'                       => 'LibreSign',
	'woocommerce_email_from_address'                    => 'noreply@example.com',
	'woocommerce_subscriptions_allow_switching'         => 'grouped',
	'woocommerce_subscriptions_apportion_recurring_price' => 'no',
	'woocommerce_subscriptions_enable_early_renewal'    => 'yes',
	'woocommerce_subscriptions_enable_retry'            => 'no',
	'woocommerce_subscriptions_multiple_purchase'       => 'yes',
	'woocommerce_subscriptions_accept_manual_renewals'  => 'yes',
	'woocommerce_subscriptions_add_to_cart_button_text' => 'Sign up now',
	'woocommerce_subscriptions_order_button_text'       => 'Sign up now',
	'woocommerce_subscriptions_switch_button_text'      => 'Upgrade',
);

wc_transaction_query( 'start' );

foreach ( $options as $name => $value ) {
	update_option( $name, $value );
}

update_option(
	'woocommerce_cod_settings',
	array(
		'enabled'            => 'yes',
		'title'              => 'Cash on delivery',
		'enable_for_virtual' => 'yes',
	)
);

$pages = array(
	'woocommerce_shop_page_id'      => 'store',
	'woocommerce_myaccount_page_id' => 'account',
);
foreach ( $pages as $option => $slug ) {
	wp_update_post(
		array(
			'ID'        => (int) get_option( $option ),
			'post_name' => $slug,
		)
	);
}

$category = wp_insert_term( 'LibreSign', 'product_cat', array( 'slug' => 'libresign' ) );

$plans = array(
	'basic'        => array(
		'name'     => 'Basic',
		'monthly'  => '55',
		'yearly'   => '660',
		'discount' => '600',
		'storage'  => '2 Gb',
		'quota'    => '2Gb',
		'features' => array( 'LibreSign' ),
		'apps'     => array( 'libresign' ),
		'featured' => true,
	),
	'professional' => array(
		'name'     => 'Professional',
		'monthly'  => '150',
		'yearly'   => '7920',
		'discount' => '7200',
		'storage'  => '120 Gb',
		'quota'    => '120Gb',
		'features' => array( 'LibreSign', 'Forms', 'Calendar', 'Task Manager', 'Document editor' ),
		'apps'     => array( 'libresign', 'forms', 'calendar', 'deck', 'onlyoffice' ),
		'featured' => false,
	),
	'enterprise'   => array(
		'name'     => 'Enterprise',
		'monthly'  => '1000',
		'yearly'   => '7920',
		'discount' => '7200',
		'storage'  => '800 Gb',
		'quota'    => '800Gb',
		'features' => array( 'LibreSign', 'Forms', 'Calendar', 'Task Manager', 'Document editor', 'Video conference', 'Suport/Consultancy', 'Custom domain', 'Custom logo', 'Custom colors' ),
		'apps'     => array( 'libresign', 'forms', 'calendar', 'deck', 'onlyoffice' ),
		'featured' => true,
	),
);

$attribute = static function ( string $name, array $options, bool $visible, bool $variation = false, int $position = 0 ): WC_Product_Attribute {
	$product_attribute = new WC_Product_Attribute();
	$product_attribute->set_name( $name );
	$product_attribute->set_options( $options );
	$product_attribute->set_visible( $visible );
	$product_attribute->set_variation( $variation );
	$product_attribute->set_position( $position );
	return $product_attribute;
};

$plan_ids = array();
foreach ( $plans as $slug => $plan ) {
	$product = new WC_Product_Variable_Subscription();
	$product->set_name( $plan['name'] );
	$product->set_slug( $slug );
	$product->set_status( 'publish' );
	$product->set_featured( $plan['featured'] );
	$product->set_sold_individually( true );
	$product->set_category_ids( array( $category['term_id'] ) );
	$product->set_default_attributes( array( 'term-length' => 'yearly' ) );
	$product->set_attributes(
		array(
			$attribute( 'Term length', array( 'monthly', 'yearly' ), true, true, 0 ),
			$attribute( 'Available features', $plan['features'], true, false, 1 ),
			$attribute( 'Storage', array( $plan['storage'] ), true, false, 2 ),
			$attribute( 'nextcloud-string-quota', array( $plan['quota'] ), false, false, 3 ),
			$attribute( 'nextcloud-list-apps', $plan['apps'], false, false, 4 ),
		)
	);
	$product->update_meta_data( '_subscription_limit', 'active' );
	$product->update_meta_data( 'restrict_herself_upsells_switch', 'yes' );
	$product->update_meta_data(
		'cfvsw_product_attr_term-length',
		array(
			'type'    => 'label',
			'monthly' => array( 'label' => 'Monthly' ),
			'yearly'  => array( 'label' => 'Yearly' ),
		)
	);
	$product->save();

	$terms = array(
		'monthly' => array( 'month', $plan['monthly'], $plan['monthly'], sprintf( '<b>Yearly</b>: $ %s,00', number_format( (float) $plan['yearly'], 0, ',', '.' ) ) ),
		'yearly'  => array( 'year', $plan['yearly'], $plan['discount'], '<b>Discount</b>: 10%' ),
	);
	foreach ( $terms as $term => list( $period, $regular_price, $price, $description ) ) {
		$variation = new WC_Product_Subscription_Variation();
		$variation->set_parent_id( $product->get_id() );
		$variation->set_attributes( array( 'term-length' => $term ) );
		$variation->set_virtual( true );
		$variation->set_regular_price( $regular_price );
		$variation->set_sale_price( $price === $regular_price ? '' : $price );
		$variation->set_description( $description );
		$variation->update_meta_data( '_subscription_price', $regular_price );
		$variation->update_meta_data( '_subscription_period', $period );
		$variation->update_meta_data( '_subscription_period_interval', 1 );
		$variation->update_meta_data( '_subscription_length', 0 );
		$variation->update_meta_data( '_subscription_sign_up_fee', 0 );
		$variation->update_meta_data( '_subscription_trial_length', 0 );
		$variation->update_meta_data( '_subscription_trial_period', 'month' );
		$variation->save();
	}

	WC_Product_Variable::sync( $product->get_id() );
	$plan_ids[ $slug ] = $product->get_id();
}

foreach ( array( 'basic', 'professional' ) as $slug ) {
	$product = wc_get_product( $plan_ids[ $slug ] );
	$product->set_upsell_ids( array( $plan_ids['enterprise'] ) );
	$product->save();
}

$upgrade = new WC_Product_Grouped();
$upgrade->set_name( 'Upgrade subscription' );
$upgrade->set_slug( 'upgrade-subscription' );
$upgrade->set_status( 'publish' );
$upgrade->set_catalog_visibility( 'hidden' );
$upgrade->set_children( array( $plan_ids['enterprise'], $plan_ids['professional'], $plan_ids['basic'] ) );
$upgrade->update_meta_data( 'restrict_herself_upsells_switch', 'no' );
$upgrade->save();

wc_transaction_query( 'commit' );
