<?php
/**
 * Plugin Name: Bookstore Importer
 * Description: Registers a custom REST endpoint `/wp-json/bookstore/v1/import` for importing books and syncing them with WooCommerce.
 * Version: 1.4
 * Author: thesimplezero
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! function_exists( 'bookstore_import_books' ) ) {

	function bookstore_import_permission_check( WP_REST_Request $request ) {
		// Check for API key in header
		$api_key      = $request->get_header( 'X-BOOKSTORE-API-KEY' );
		$expected_key = getenv( 'BOOKSTORE_API_KEY' );

		if ( $api_key && $expected_key && $api_key === $expected_key ) {
			return true;
		}

		// Fallback to WP capability (for testing inside admin)
		return current_user_can( 'manage_options' );
	}

	function bookstore_import_books( WP_REST_Request $request ) {
		$books    = $request->get_json_params();
		$imported = [];

		if ( empty( $books ) || ! is_array( $books ) ) {
			return new WP_REST_Response(
				[ 'error' => 'Invalid payload format.' ],
				400
			);
		}

		foreach ( $books as $book ) {
			// Defensive defaults
			$title  = sanitize_text_field( $book['book_title'] ?? 'Untitled Book' );
			$author = sanitize_text_field( $book['author'] ?? 'Unknown Author' );
			$isbn   = sanitize_text_field( $book['isbn'] ?? uniqid( 'isbn_' ) );
			$price  = floatval( $book['price'] ?? 0 );

			// create Book CPT entry
			$book_id = wp_insert_post( [
				'post_type'   => 'book',
				'post_title'  => $title,
				'post_status' => 'publish',
			] );

			if ( is_wp_error( $book_id ) ) {
				$imported[] = [
					'book_title' => $title,
					'author'     => $author,
					'isbn'       => $isbn,
					'price'      => $price,
					'status'     => 'error',
					'message'    => $book_id->get_error_message(),
				];
				continue;
			}

			update_post_meta( $book_id, 'isbn', $isbn );
			update_post_meta( $book_id, 'author', $author );
			update_post_meta( $book_id, 'price', $price );

			// create linked WooCommerce product
			if ( class_exists( 'WC_Product_Simple' ) ) {
				$product = new WC_Product_Simple();
				$product->set_name( $title );
				$product->set_regular_price( $price );
				$product->set_sku( $isbn );
				$product->set_stock_status( 'instock' );
				$product->save();

				// Cross-link both sides
				update_post_meta( $book_id, 'linked_product_id', $product->get_id() );
				update_post_meta( $product->get_id(), 'linked_book_id', $book_id );

				$imported[] = [
					'book_title' => $title,
					'author'     => $author,
					'isbn'       => $isbn,
					'price'      => $price,
					'status'     => 'imported',
					'book_id'    => $book_id,
					'product_id' => $product->get_id(),
				];
			} else {
				$imported[] = [
					'book_title' => $title,
					'author'     => $author,
					'isbn'       => $isbn,
					'price'      => $price,
					'status'     => 'error',
					'message'    => 'WooCommerce not active',
				];
			}
		}

		return new WP_REST_Response( [ 'imported' => $imported ], 200 );
	}
}

// --- Register the REST endpoint ---
add_action( 'rest_api_init', function () {
	register_rest_route(
		'bookstore/v1',
		'/import',
		[
			'methods'             => 'POST',
			'callback'            => 'bookstore_import_books',
			'permission_callback' => 'bookstore_import_permission_check',
		]
	);
} );

/**
 * Admin columns for Book CPT: show author, isbn, price, and make isbn/price sortable.
 */

add_filter( 'manage_book_posts_columns', 'bookstore_admin_columns' );
function bookstore_admin_columns( $columns ) {
	// keep checkbox and title, then add our fields, keep date
	$new = [];
	$new['cb']    = $columns['cb'] ?? '<input type="checkbox" />';
	$new['title'] = $columns['title'] ?? 'Title';
	$new['author_meta'] = 'Author';
	$new['isbn']   = 'ISBN';
	$new['price']  = 'Price';
	$new['date']   = $columns['date'] ?? 'Date';
	return $new;
}

add_action( 'manage_book_posts_custom_column', 'bookstore_admin_render_columns', 10, 2 );
function bookstore_admin_render_columns( $column, $post_id ) {
	switch ( $column ) {
		case 'author_meta':
			$val = get_post_meta( $post_id, 'author', true );
			echo $val ? esc_html( $val ) : '—';
			break;

		case 'isbn':
			$val = get_post_meta( $post_id, 'isbn', true );
			echo $val ? '<code>' . esc_html( $val ) . '</code>' : '—';
			break;

		case 'price':
			$val = get_post_meta( $post_id, 'price', true );
			if ( $val === '' || $val === null ) {
				echo '—';
			} else {
				// format numeric price; adjust currency display to suit you
				echo esc_html( number_format_i18n( floatval( $val ), 2 ) );
			}
			break;
	}
}

/* Make columns sortable */
add_filter( 'manage_edit-book_sortable_columns', 'bookstore_book_sortable_columns' );
function bookstore_book_sortable_columns( $cols ) {
	$cols['isbn']  = 'isbn';
	$cols['price'] = 'price';
	return $cols;
}

/* Handle sorting by meta keys for admin queries */
add_action( 'pre_get_posts', 'bookstore_book_orderby_meta' );
function bookstore_book_orderby_meta( $query ) {
	if ( ! is_admin() || ! $query->is_main_query() ) {
		return;
	}

	$post_type = $query->get( 'post_type' );
	if ( 'book' !== $post_type ) {
		return;
	}

	$orderby = $query->get( 'orderby' );
	if ( 'price' === $orderby ) {
		$query->set( 'meta_key', 'price' );
		$query->set( 'orderby', 'meta_value_num' );
	} elseif ( 'isbn' === $orderby ) {
		$query->set( 'meta_key', 'isbn' );
		$query->set( 'orderby', 'meta_value' );
	}
}

/* show meta on the single Book view (frontend) */
add_filter( 'the_content', 'bookstore_book_append_meta_to_content' );
function bookstore_book_append_meta_to_content( $content ) {
	if ( ! is_singular( 'book' ) || ! in_the_loop() ) {
		return $content;
	}

	$post_id = get_the_ID();
	$author = get_post_meta( $post_id, 'author', true );
	$isbn   = get_post_meta( $post_id, 'isbn', true );
	$price  = get_post_meta( $post_id, 'price', true );

	$html = '<div class="book-meta" style="margin-top:1.25rem;padding:1rem;border-top:1px solid #eee;">';
	if ( $author ) {
		$html .= '<p><strong>Author:</strong> ' . esc_html( $author ) . '</p>';
	}
	if ( $isbn ) {
		$html .= '<p><strong>ISBN:</strong> <code>' . esc_html( $isbn ) . '</code></p>';
	}
	if ( $price !== '' && $price !== null ) {
		$html .= '<p><strong>Price:</strong> ' . esc_html( number_format_i18n( floatval( $price ), 2 ) ) . '</p>';
	}
	$html .= '</div>';

	return $content . $html;
}
