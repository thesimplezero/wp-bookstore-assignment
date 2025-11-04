# Dockerfile — WordPress All-in-One Container
FROM wordpress:php8.4-apache

# -----------------------------
# Environment variables (defaults - override via docker-compose)
# -----------------------------
ENV WORDPRESS_DB_HOST=db:3306 \
    WORDPRESS_DB_USER=wordpress \
    WORDPRESS_DB_PASSWORD=wordpress \
    WORDPRESS_DB_NAME=wordpress \
    FS_METHOD=direct \
    PHP_UPLOAD_MAX_FILESIZE=1024M \
    PHP_POST_MAX_SIZE=1024M \
    PHP_MEMORY_LIMIT=512M

# -----------------------------
# Install OS packages (single RUN for better layer caching)
# -----------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        less \
        git \
        unzip \
        curl \
        mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------
# Enable Apache modules
# -----------------------------
RUN a2enmod rewrite headers expires

# -----------------------------
# PHP configuration optimizations
# -----------------------------
RUN { \
    echo 'upload_max_filesize = 1024M'; \
    echo 'post_max_size = 1024M'; \
    echo 'memory_limit = 512M'; \
    echo 'max_execution_time = 300'; \
    echo 'max_input_time = 300'; \
    } > /usr/local/etc/php/conf.d/uploads.ini

# -----------------------------
# Copy custom entrypoint script
# -----------------------------
COPY docker-entrypoint-custom.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint-custom.sh

# -----------------------------
# Ensure wp-content is writable by the webserver
# -----------------------------
RUN mkdir -p /var/www/html/wp-content \
    && chown -R www-data:www-data /var/www/html/wp-content \
    && chmod -R 755 /var/www/html/wp-content

EXPOSE 80

# Use custom entrypoint that wraps the original
ENTRYPOINT ["docker-entrypoint-custom.sh"]
CMD ["apache2-foreground"]
