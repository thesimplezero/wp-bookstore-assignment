# Bookstore Importer

A WordPress plugin system for importing books from CSV files and automatically syncing them with WooCommerce products. Designed for bookstore inventory management with automated batch imports and bidirectional product linking.

# Overview

This project provides a complete solution for managing a bookstore's inventory through WordPress and WooCommerce:

- **Custom Post Type**: Registers a `book` CPT with metadata (ISBN, author, price)
- **REST API Endpoint**: `/wp-json/bookstore/v1/import` for programmatic imports
- **WooCommerce Integration**: Automatically creates and links WooCommerce products
- **Batch Import Tools**: Python scripts for automated, continuous imports
- **Docker Environment**: Complete development stack with WordPress, MariaDB, and Adminer

## Architecture

### Plugin Components

**bookstore-importer.php**
- Registers REST endpoint with API key authentication
- Creates Book CPT entries with metadata
- Generates linked WooCommerce products with SKU matching
- Provides admin columns for Book management
- Displays book metadata on frontend

**functions.php**
- Registers the `book` custom post type
- Enables REST API and archive support

### Data Flow

```
CSV File → Python Script → REST API → WordPress Plugin
                                          ├─→ Book CPT (with metadata)
                                          └─→ WooCommerce Product (linked)
```

### Bidirectional Linking

Each import creates cross-references:
- `linked_product_id` on Book → WooCommerce Product ID
- `linked_book_id` on Product → Book CPT ID

This enables future synchronization of stock, pricing, and metadata changes.

## Import Tools

### auto-import-books.py

Automated batch importer for continuous testing and data population:

**Features:**
- Parses Book-Crossing dataset format (8 columns)
- Configurable batch size and interval
- Graceful shutdown handling (Ctrl+C)
- API key or WordPress user authentication
- Network error recovery
- Real-time statistics and progress reporting

**Configuration (.env):**
```env
BOOKS_CSV_PATH=data/books.csv
WORDPRESS_API_URL=http://localhost:8080/wp-json/bookstore/v1/import
BOOKSTORE_API_KEY=your_secret_key
AUTO_ITEMS_PER_BATCH=3
AUTO_BATCH_INTERVAL=10
AUTO_MAX_BATCHES=0  # 0 = unlimited
```

**CSV Format:**
```
ISBN,Book-Title,Book-Author,Year-Of-Publication,Publisher,Image-URL-S,Image-URL-M,Image-URL-L
0195153448,Classical Mythology,Mark P. O. Morford,2002,Oxford University Press,...
```

### generate_fake_books.py

Test data generator using Faker library:

```bash
python generate_fake_books.py 100  # Generate 100 books
```

Creates realistic book data with:
- Valid ISBN formats (10 or 13 digits)
- Plausible titles and authors
- Random publishers and publication years
- Mock Amazon-style image URLs
- Consistent pricing ($10-$60)

## Developer Environment

### Docker Stack

The project includes a complete Docker Compose setup for local development:

**Services:**
- **wordpress**: Custom WordPress image with WooCommerce pre-configured
- **db**: MariaDB 11 with optimized settings for WordPress
- **adminer**: Database management UI (port 8081)
- **cron**: Automated background tasks (optional scheduled imports)

**Features:**
- Health checks for service dependencies
- Persistent database volumes
- PHP configuration optimized for large uploads (1GB max)
- Development utilities (curl, vim, nano) pre-installed
- Custom scripts mounting for import automation

### Quick Start

1. **Clone and configure:**
```bash
cp .env.example .env
# Edit .env with your settings
```

2. **Start services:**
```bash
docker-compose up -d
```

3. **Access WordPress:**
- Site: http://localhost:8080
- Admin: http://localhost:8080/wp-admin
- Database: http://localhost:8081 (Adminer)

4. **Install plugin:**
```bash
# Plugin is auto-mounted via volumes
# Activate in WordPress admin or via WP-CLI
```

5. **Generate test data:**
```bash
python generate_fake_books.py 50
```

6. **Run importer:**
```bash
python auto-import-books.py
```

### PHP Configuration

**uploads.ini** provides production-ready settings:
- 1GB upload limit for bulk imports
- 512MB memory limit
- 5-minute execution timeout
- Opcache enabled for performance
- Enhanced security (expose_php off, httponly cookies)

### Network Architecture

All services communicate via the `wp-network` bridge network:
- Database isolated from host
- Internal service discovery by container name
- Only WordPress and Adminer expose ports to host

## Authentication

The REST endpoint supports two authentication methods:

### 1. API Key (Recommended)
```bash
curl -X POST http://localhost:8080/wp-json/bookstore/v1/import \
  -H "Content-Type: application/json" \
  -H "X-BOOKSTORE-API-KEY: your_secret_key" \
  -d '[{"isbn":"123","book_title":"Test","author":"Author","price":29.99}]'
```

Set via environment variable: `BOOKSTORE_API_KEY`

### 2. WordPress User Auth
```bash
curl -X POST http://localhost:8080/wp-json/bookstore/v1/import \
  -u username:password \
  -H "Content-Type: application/json" \
  -d '[...]'
```

User must have `manage_options` capability.

## API Response Format

```json
{
  "imported": [
    {
      "book_title": "Classical Mythology",
      "author": "Mark P. O. Morford",
      "isbn": "0195153448",
      "price": 29.99,
      "status": "imported",
      "book_id": 123,
      "product_id": 456
    }
  ]
}
```

**Status Values:**
- `imported`: Successfully created both Book and Product
- `error`: Failed (includes `message` field)


## Troubleshooting

### Issues faced

**"WooCommerce not active" error:**
- Install and activate WooCommerce plugin
- Check plugin dependencies in `composer.json`

**Permission denied on import:**
- Verify API key matches environment variable
- Check user has `manage_options` capability
- Review WordPress authentication settings

**CSV parsing errors:**
- Ensure CSV has 8 columns (even if some are empty)
- Check UTF-8 encoding
- Verify no header row conflicts with data

**Database connection failures:**
- Wait for DB health check to pass (~30s on first start)
- Check `.env` credentials match docker-compose
- Verify `wp-network` bridge is created

### Debug Mode

Enable WordPress debug logging in `wp-config.php`:
```php
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);
```

Check logs at `wp-content/debug.log`

## Performance Considerations

- **Batch Size**: Larger batches (10-50) reduce API overhead but may timeout
- **Import Interval**: Minimum 5s recommended to avoid database locks
- **Database Indexing**: ISBN and price fields are indexed via meta queries
- **Opcache**: Enabled by default in Docker environment
- **MariaDB Buffer**: Configured with 512MB innodb_buffer_pool_size


## License

GPL v2 or later
