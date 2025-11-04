<?php
// wp-config-overrides.php â€” development overrides (safe-guarded)


if ( ! defined( 'WP_DEBUG' ) ) {
define( 'WP_DEBUG', true );
}


// Force direct writes so plugins/themes can be installed in dev
if ( ! defined( 'FS_METHOD' ) ) {
define( 'FS_METHOD', 'direct' );
}


@ini_set( 'upload_max_filesize', getenv('PHP_UPLOAD_MAX_FILESIZE') ?: '1024M' );
@ini_set( 'post_max_size', getenv('PHP_POST_MAX_SIZE') ?: '1024M' );
@ini_set( 'memory_limit', getenv('PHP_MEMORY_LIMIT') ?: '512M' );


// Recommended dev niceties â€” disable automatic updates and file edits in container dev
if ( ! defined( 'AUTOMATIC_UPDATER_DISABLED' ) ) {
define( 'AUTOMATIC_UPDATER_DISABLED', true );
}
if ( ! defined( 'DISALLOW_FILE_EDIT' ) ) {
define( 'DISALLOW_FILE_EDIT', false ); // allow theme/plugin editor if you want; set to true to lock
}


// Optionally set salts from environment or leave to the base wp-config
// (You can generate salts via: https://api.wordpress.org/secret-key/1.1/salt/ )
