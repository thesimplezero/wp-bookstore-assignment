#!/usr/bin/env python3
"""
generate_fake_books.py
Generate random, realistic-looking book data for testing importers.
Usage:
    python generate_fake_books.py 100
(default = 50)
"""

import csv, os, sys, random, string
from faker import Faker
fake = Faker()

# Number of books to generate
try:
    NUM_BOOKS = int(sys.argv[1])
except (IndexError, ValueError):
    NUM_BOOKS = 50

# Output path
OUTPUT_DIR = "data"
os.makedirs(OUTPUT_DIR, exist_ok=True)
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "books.csv")

# CSV headers to match importer expectations
FIELDS = [
    "ISBN",
    "Book-Title",
    "Book-Author",
    "Year-Of-Publication",
    "Publisher",
    "Image-URL-S",
    "Image-URL-M",
    "Image-URL-L",
]

# Helper functions
def random_isbn():
    """Generate a realistic 10 or 13 digit ISBN"""
    if random.random() > 0.5:
        prefix = random.choice(["978", "979"])
        return prefix + ''.join(random.choices(string.digits, k=10))
    else:
        return ''.join(random.choices(string.digits, k=10))

def random_title():
    """Generate a plausible book title"""
    templates = [
        "The {adj} {noun}",
        "{noun} of {place}",
        "A Study in {topic}",
        "Chronicles of {noun}",
        "Beneath the {adj} {thing}",
        "The Art of {verb}",
        "Voices from {place}",
        "Secrets of the {noun}",
        "Journey to {place}",
        "Letters to {person}",
    ]
    template = random.choice(templates)
    subs = {
        "adj": fake.word().capitalize(),
        "noun": fake.word().capitalize(),
        "place": fake.city(),
        "thing": fake.word().capitalize(),
        "topic": fake.word().capitalize(),
        "verb": fake.word().capitalize(),
        "person": fake.first_name(),
    }
    return template.format(**subs)

def random_publisher():
    """Generate publisher names with realism"""
    prefixes = ["Harper", "Penguin", "Oxford", "Cambridge", "Random", "Vintage", "Crown", "Beacon", "Farrar", "Houghton"]
    suffixes = ["Press", "Publishing", "House", "Books", "Group", "Editions"]
    return f"{random.choice(prefixes)} {random.choice(suffixes)}"

def random_price():
    """Return a price between 10.00 and 60.00"""
    return round(random.uniform(10, 60), 2)

def random_image_urls(isbn):
    """Return Amazon-style image URLs"""
    base = f"http://images.amazon.com/images/P/{isbn}.01"
    return (
        f"{base}.THUMBZZZ.jpg",
        f"{base}.MZZZZZZZ.jpg",
        f"{base}.LZZZZZZZ.jpg"
    )

# Generate book data
books = []
for _ in range(NUM_BOOKS):
    isbn = random_isbn()
    title = random_title()
    author = fake.name()
    year = random.randint(1950, 2025)
    publisher = random_publisher()
    thumb, medium, large = random_image_urls(isbn)

    books.append({
        "ISBN": isbn,
        "Book-Title": title,
        "Book-Author": author,
        "Year-Of-Publication": year,
        "Publisher": publisher,
        "Image-URL-S": thumb,
        "Image-URL-M": medium,
        "Image-URL-L": large
    })

# Write to CSV
with open(OUTPUT_FILE, "w", newline='', encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=FIELDS)
    writer.writeheader()
    writer.writerows(books)

print(f"✅ Generated {len(books)} fake books → {OUTPUT_FILE}")
