#!/usr/bin/env python3
"""
auto-import-books.py
Automatically imports books in batches at regular intervals for testing.
Parses standard Book-Crossing dataset fields.
Press Ctrl+C to stop gracefully.
"""

import csv, json, os, sys, time, signal, html
from datetime import datetime
import random
import requests
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv

load_dotenv()

# Config from .env
CSV_PATH = os.getenv("BOOKS_CSV_PATH", "data/books.csv")
WP_API_URL = os.getenv("WORDPRESS_API_URL", "http://localhost:8080/wp-json/bookstore/v1/import")
WP_USER = os.getenv("WORDPRESS_USERNAME", "")
WP_PASS = os.getenv("WORDPRESS_PASSWORD", "")
API_KEY = os.getenv("BOOKSTORE_API_KEY", "")
ITEMS_PER_BATCH = int(os.getenv("AUTO_ITEMS_PER_BATCH", "3"))
BATCH_INTERVAL = int(os.getenv("AUTO_BATCH_INTERVAL", "10"))  # seconds
MAX_BATCHES = int(os.getenv("AUTO_MAX_BATCHES", "0"))  # 0 = unlimited
REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "30"))

# Graceful shutdown
shutdown_requested = False
def signal_handler(sig, frame):
    global shutdown_requested
    print("\n\n🛑 Shutdown requested. Finishing current batch...")
    shutdown_requested = True
signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# Validate source
if not os.path.exists(CSV_PATH):
    print(f"❌ ERROR: CSV file not found at {CSV_PATH}")
    sys.exit(2)

# Load and parse CSV
print(f"📚 Loading books from {CSV_PATH}...")
all_books = []
with open(CSV_PATH, newline='', encoding='utf-8') as f:
    # Use csv.reader for files without headers
    reader = csv.reader(f)
    
    # Expected column order from user's example:
    # 0: ISBN
    # 1: Book-Title
    # 2: Book-Author
    # 3: Year-Of-Publication
    # 4: Publisher
    # 5: Image-URL-S
    # 6: Image-URL-M
    # 7: Image-URL-L
    
    for i, row in enumerate(reader, start=1):
        try:
            # Check if row has enough columns (at least 8 for the large image URL)
            if len(row) < 8:
                print(f"⚠️  Skipped row {i}: Incomplete data (found {len(row)} columns, expected 8)")
                continue

            # Access by index
            isbn = row[0].strip()
            title = row[1].strip()
            author = row[2].strip()
            year_str = row[3].strip()
            publisher = html.unescape(row[4].strip())
            # Use the large image URL, which is at index 7
            image_url = row[7].strip() 

            # Validate year
            year = 0
            if year_str.isdigit():
                year = int(year_str)

            # Skip invalid records
            if not (isbn and title):
                print(f"⚠️  Skipped row {i}: Missing ISBN or Title")
                continue

            # Demo price generator (stable but varied)
            random.seed(isbn)
            price = round(random.uniform(10.0, 60.0), 2)

            # Construct normalized payload
            book = {
                "isbn": isbn,
                "title": title,
                "author": author or "Unknown",
                "year": year if year > 0 else None,
                "publisher": publisher or "Unknown Publisher",
                "image_url": image_url,
                "price": price,
            }
            all_books.append(book)

        except Exception as e:
            print(f"⚠️  Skipped row {i}: {e}")

if not all_books:
    print("❌ No valid books found in CSV.")
    sys.exit(0)

print(f"✅ Parsed {len(all_books)} valid books\n")

# Authentication
headers = {"Content-Type": "application/json"}
auth = None
if API_KEY:
    headers["X-BOOKSTORE-API-KEY"] = API_KEY
    print("🔐 Using API Key authentication")
elif WP_USER and WP_PASS:
    auth = HTTPBasicAuth(WP_USER, WP_PASS)
    print(f"🔐 Using WordPress authentication (user: {WP_USER})")
else:
    print("❌ ERROR: No authentication configured.")
    sys.exit(2)

print(f"🎯 Target: {WP_API_URL}")
print(f"⚙️  Config: {ITEMS_PER_BATCH} items/batch, every {BATCH_INTERVAL}s")
if MAX_BATCHES > 0:
    print(f"⚙️  Will stop after {MAX_BATCHES} batches\n")
else:
    print(f"⚙️  Continuous import (Ctrl+C to stop)\n")
print("=" * 60)

# Stats
stats = {"batches_sent": 0, "items_imported": 0, "items_failed": 0, "errors": 0}

def print_stats():
    print(f"\n📊 Stats: batches={stats['batches_sent']} ok={stats['items_imported']} failed={stats['items_failed']} neterr={stats['errors']}")

def post_batch(batch, batch_num):
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] 📤 Batch #{batch_num} → {len(batch)} books")

    try:
        resp = requests.post(WP_API_URL, json=batch, headers=headers, auth=auth, timeout=REQUEST_TIMEOUT)
        if resp.status_code >= 400:
            print(f"   ❌ HTTP {resp.status_code}: {resp.reason}")
            try:
                print(f"   Details: {resp.json()}")
            except:
                print(f"   Raw: {resp.text[:200]}")
            stats['errors'] += 1
            return False

        result = resp.json()
        imported = result.get("imported", [])
        success = sum(1 for i in imported if i.get("status") == "imported")
        fail = sum(1 for i in imported if i.get("status") == "failed")

        stats["items_imported"] += success
        stats["items_failed"] += fail
        print(f"   ✅ Imported: {success} | ❌ Failed: {fail}")
        if imported:
            samples = [i.get("book", "Unknown")[:40] for i in imported[:3]]
            print(f"   📖 {', '.join(samples)}{'...' if len(imported) > 3 else ''}")
        return True

    except requests.RequestException as e:
        print(f"   ❌ Network error: {e}")
        stats["errors"] += 1
        return False

# Main loop
current = 0
try:
    while not shutdown_requested:
        stats["batches_sent"] += 1
        batch = [all_books[(current + i) % len(all_books)] for i in range(ITEMS_PER_BATCH)]
        current = (current + ITEMS_PER_BATCH) % len(all_books)

        post_batch(batch, stats["batches_sent"])

        if MAX_BATCHES > 0 and stats["batches_sent"] >= MAX_BATCHES:
            print(f"\n✅ Reached {MAX_BATCHES} batches — exiting.")
            break

        print(f"   ⏳ Waiting {BATCH_INTERVAL}s...\n")
        for _ in range(BATCH_INTERVAL):
            if shutdown_requested:
                break
            time.sleep(1)

except Exception as e:
    print(f"\n❌ Fatal: {e}")
    import traceback; traceback.print_exc()

finally:
    print("\n" + "="*60)
    print_stats()
    print("\n✅ Import process stopped.")
