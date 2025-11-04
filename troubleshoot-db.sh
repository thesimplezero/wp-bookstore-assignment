#!/bin/bash

# MariaDB Troubleshooting Script
# Run this if MariaDB fails to start

echo "============================================"
echo "MariaDB Troubleshooting Script"
echo "============================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if containers are running
echo "1. Checking container status..."
docker-compose ps
echo ""

# Check MariaDB logs
echo "2. Recent MariaDB logs:"
echo "============================================"
docker-compose logs --tail=50 db
echo ""

# Check if volume has data
echo "3. Checking database volume..."
docker volume inspect wp_bookstore_db_data >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Database volume exists"
else
    echo -e "${RED}✗${NC} Database volume not found"
fi
echo ""

# Check environment variables
echo "4. Checking environment variables..."
if [ -f .env ]; then
    echo -e "${GREEN}✓${NC} .env file exists"
    echo "Database configuration:"
    grep -E "^(DB_|MYSQL_)" .env | sed 's/=.*/=***/' || echo "No database variables found"
else
    echo -e "${RED}✗${NC} .env file not found!"
fi
echo ""

# Check for port conflicts
echo "5. Checking for port conflicts..."
if lsof -i :3306 >/dev/null 2>&1 || netstat -an | grep -q ":3306.*LISTEN" 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC} Port 3306 may be in use"
    echo "Run: sudo lsof -i :3306"
else
    echo -e "${GREEN}✓${NC} Port 3306 is available"
fi
echo ""

# Provide solutions
echo "============================================"
echo "Common Solutions:"
echo "============================================"
echo ""
echo "Problem 1: Container exits immediately"
echo "  Solution: Check logs above for error messages"
echo "  Command: docker-compose logs db"
echo ""
echo "Problem 2: Permission denied errors"
echo "  Solution: Reset database volume"
echo "  Commands:"
echo "    docker-compose down -v"
echo "    docker volume rm wp_bookstore_db_data"
echo "    docker-compose up -d"
echo ""
echo "Problem 3: Password authentication failed"
echo "  Solution: Ensure passwords match in .env"
echo "  Check: DB_PASSWORD and MYSQL_ROOT_PASSWORD"
echo ""
echo "Problem 4: Corrupt database"
echo "  Solution: Reset and restore from backup"
echo "  Commands:"
echo "    docker-compose down"
echo "    docker volume rm wp_bookstore_db_data"
echo "    docker-compose up -d"
echo "    # Then restore: docker-compose exec -T db mysql -u root -p < backup.sql"
echo ""
echo "Problem 5: Out of disk space"
echo "  Solution: Check available space"
echo "  Command: df -h"
echo ""

# Offer to reset
echo "============================================"
read -p "Do you want to reset the database? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Stopping containers..."
    docker-compose down
    
    echo "Removing database volume..."
    docker volume rm wp_bookstore_db_data
    
    echo "Starting containers..."
    docker-compose up -d
    
    echo ""
    echo "Database reset complete. Check status:"
    sleep 5
    docker-compose ps
    docker-compose logs db
else
    echo "No changes made."
fi