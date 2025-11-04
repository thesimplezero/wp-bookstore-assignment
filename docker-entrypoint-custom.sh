#!/bin/bash
set -euo pipefail

# ============================================================================
# Custom WordPress Docker Entrypoint
# ============================================================================
# This script runs before the official WordPress entrypoint and handles:
# - Database connection waiting with timeout
# - WordPress configuration validation
# - Permission fixes
# - Health checks
# ============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MAX_WAIT_TIME=120  # Maximum seconds to wait for database
SLEEP_INTERVAL=2   # Seconds between connection attempts

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# Database Connection Check
# ============================================================================

wait_for_database() {
    log_info "Starting database connection check..."
    
    # Extract host and port from WORDPRESS_DB_HOST
    local db_host="${WORDPRESS_DB_HOST%%:*}"
    local db_port="${WORDPRESS_DB_HOST##*:}"
    
    # Default to 3306 if port not specified
    if [ "$db_port" = "$db_host" ]; then
        db_port="3306"
    fi
    
    log_info "Database host: $db_host"
    log_info "Database port: $db_port"
    log_info "Database name: ${WORDPRESS_DB_NAME}"
    log_info "Database user: ${WORDPRESS_DB_USER}"
    
    local elapsed=0
    local connected=false
    
    # Wait for database with timeout
    while [ $elapsed -lt $MAX_WAIT_TIME ]; do
        if mysqladmin ping \
            -h"$db_host" \
            -P"$db_port" \
            -u"${WORDPRESS_DB_USER}" \
            -p"${WORDPRESS_DB_PASSWORD}" \
            --silent 2>/dev/null; then
            connected=true
            break
        fi
        
        log_warn "Database is unavailable - waiting... (${elapsed}s/${MAX_WAIT_TIME}s)"
        sleep $SLEEP_INTERVAL
        elapsed=$((elapsed + SLEEP_INTERVAL))
    done
    
    if [ "$connected" = false ]; then
        log_error "Database connection timeout after ${MAX_WAIT_TIME} seconds"
        log_error "Please check:"
        log_error "  1. Database container is running: docker-compose ps"
        log_error "  2. Database credentials in .env file"
        log_error "  3. Network connectivity: docker-compose logs db"
        exit 1
    fi
    
    log_info "✓ Database connection established successfully"
}

# ============================================================================
# Database Verification
# ============================================================================

verify_database() {
    log_info "Verifying database access..."
    
    local db_host="${WORDPRESS_DB_HOST%%:*}"
    local db_port="${WORDPRESS_DB_HOST##*:}"
    
    if [ "$db_port" = "$db_host" ]; then
        db_port="3306"
    fi
    
    # Try to list databases to verify permissions
    if mysql \
        -h"$db_host" \
        -P"$db_port" \
        -u"${WORDPRESS_DB_USER}" \
        -p"${WORDPRESS_DB_PASSWORD}" \
        -e "USE ${WORDPRESS_DB_NAME}; SELECT 1;" \
        &>/dev/null; then
        log_info "✓ Database access verified"
    else
        log_error "Cannot access database '${WORDPRESS_DB_NAME}'"
        log_error "Verify database exists and user has proper permissions"
        exit 1
    fi
}

# ============================================================================
# WordPress Directory Permissions
# ============================================================================

fix_permissions() {
    log_info "Checking WordPress directory permissions..."
    
    # Ensure wp-content exists and is writable
    if [ -d "/var/www/html/wp-content" ]; then
        # Fix ownership
        chown -R www-data:www-data /var/www/html/wp-content 2>/dev/null || true
        
        # Set appropriate permissions
        find /var/www/html/wp-content -type d -exec chmod 755 {} \; 2>/dev/null || true
        find /var/www/html/wp-content -type f -exec chmod 644 {} \; 2>/dev/null || true
        
        log_info "✓ Permissions updated for wp-content"
    else
        log_warn "wp-content directory not found - will be created by WordPress"
    fi
}

# ============================================================================
# Environment Validation
# ============================================================================

validate_environment() {
    log_info "Validating environment variables..."
    
    local required_vars=(
        "WORDPRESS_DB_HOST"
        "WORDPRESS_DB_USER"
        "WORDPRESS_DB_PASSWORD"
        "WORDPRESS_DB_NAME"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        exit 1
    fi
    
    log_info "✓ All required environment variables are set"
}

# ============================================================================
# Health Check
# ============================================================================

perform_health_check() {
    log_info "Performing pre-startup health checks..."
    
    # Check disk space
    local disk_usage=$(df -h /var/www/html | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        log_warn "Disk usage is high: ${disk_usage}%"
    else
        log_info "✓ Disk space: ${disk_usage}% used"
    fi
    
    # Check PHP configuration
    if [ -f "/usr/local/etc/php/conf.d/uploads.ini" ]; then
        log_info "✓ Custom PHP configuration loaded"
    else
        log_warn "Custom PHP configuration not found"
    fi
    
    # Verify Apache modules
    if apache2ctl -M 2>/dev/null | grep -q "rewrite_module"; then
        log_info "✓ Apache rewrite module enabled"
    else
        log_warn "Apache rewrite module not detected"
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    log_info "════════════════════════════════════════════════════════"
    log_info "  WordPress Container Custom Entrypoint"
    log_info "════════════════════════════════════════════════════════"
    
    # Step 1: Validate environment
    validate_environment
    
    # Step 2: Wait for database
    wait_for_database
    
    # Step 3: Verify database access
    verify_database
    
    # Step 4: Fix permissions
    fix_permissions
    
    # Step 5: Perform health checks
    perform_health_check
    
    log_info "════════════════════════════════════════════════════════"
    log_info "  Pre-flight checks complete - Starting WordPress"
    log_info "════════════════════════════════════════════════════════"
    
    # Execute the original WordPress entrypoint with all arguments
    exec docker-entrypoint.sh "$@"
}

# Run main function
main "$@"
