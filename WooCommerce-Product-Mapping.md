# WooCommerce Product Mapping Documentation

## Overview
The **Bookstore Importer** plugin creates a bidirectional relationship between custom **Book** posts and **WooCommerce** products, enabling synchronized inventory management for a bookstore.

## Mapping Logic

When books are imported via the REST endpoint `/wp-json/bookstore/v1/import`, the plugin performs the following steps:

1. **Creates Book CPT Entry**  
   Creates a `book` custom post type with title and metadata (ISBN, author, price).

2. **Generates WooCommerce Product**  
   Instantiates a `WC_Product_Simple` object with matching attributes.

3. **Establishes Cross-Links**  
   Stores bidirectional references using post meta:
   - **Book → Product:** `linked_product_id` meta field  
   - **Product → Book:** `linked_book_id` meta field  

### Key Features
- **ISBN as SKU:** Uses the book's ISBN as the WooCommerce product SKU for inventory tracking.  
- **Price Synchronization:** Sets the product's regular price from the book's price field.  
- **Stock Status:** Automatically marks products as *in stock*.  
- **Error Handling:** Returns detailed status for each import operation.

## Data Flow
The import process handles each book sequentially — creating both the Book CPT and WooCommerce product, then establishing the bidirectional link through post metadata for future synchronization needs.
