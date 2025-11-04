<?php
// Register Custom Post Type: Book
add_action('init', function() {
    $labels = [
        'name' => 'Books',
        'singular_name' => 'Book',
        'menu_name' => 'Books',
        'add_new_item' => 'Add New Book',
        'edit_item' => 'Edit Book',
    ];
    $args = [
        'labels' => $labels,
        'public' => true,
        'show_in_rest' => true,
        'supports' => ['title', 'editor', 'thumbnail'],
        'has_archive' => true,
        'rewrite' => ['slug' => 'books'],
    ];
    register_post_type('book', $args);
});