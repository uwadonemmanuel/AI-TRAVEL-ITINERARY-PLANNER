#!/usr/bin/env python3
"""Copy all .whl files from Downloads to project downloads folder"""

import os
import shutil
from pathlib import Path

downloads_source = Path("/Users/emmanuel/Downloads")
downloads_dest = Path("/Users/emmanuel/Documents/Projects/Andela GenAI/LLMOPS/AI-TRAVEL-ITINEARY-PLANNER/downloads")

# Ensure destination exists
downloads_dest.mkdir(parents=True, exist_ok=True)

# Find all .whl files
whl_files = list(downloads_source.glob("*.whl"))

if not whl_files:
    print(f"No .whl files found in {downloads_source}")
    exit(0)

print(f"Found {len(whl_files)} .whl file(s) in Downloads")
print(f"Copying to {downloads_dest}\n")

copied = 0
skipped = 0
errors = 0

for whl_file in whl_files:
    dest_file = downloads_dest / whl_file.name
    
    try:
        if dest_file.exists():
            print(f"  ⚠ Skipping {whl_file.name} (already exists)")
            skipped += 1
        else:
            shutil.copy2(whl_file, dest_file)
            print(f"  ✓ Copied {whl_file.name}")
            copied += 1
    except Exception as e:
        print(f"  ✗ Error copying {whl_file.name}: {e}")
        errors += 1

print(f"\n{'='*60}")
print(f"Summary:")
print(f"  Copied: {copied}")
print(f"  Skipped: {skipped}")
print(f"  Errors: {errors}")
print(f"{'='*60}")


