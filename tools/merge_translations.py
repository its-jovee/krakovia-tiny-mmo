#!/usr/bin/env python3
"""
Merge Portuguese translations from an external CSV into localization/translations.csv.

Assumptions:
- Target file format: key,English,Portuguese with optional comment lines starting with '#'
- Fields may contain commas escaped with a backslash: \,
- Source CSV (e.g., from Downloads) is standard CSV with header: keys,en,pt_BR

Default behavior merges only item_* keys.
"""
import argparse
import csv
import os
import re
import shutil
import sys
from datetime import datetime


def split_repo_line(line: str):
    """Split a repo CSV line into up to 3 fields by commas not preceded by backslash.
    Returns (key, en, pt) or (None, None, None) if not a data line.
    """
    s = line.rstrip("\n\r")
    if not s or s.lstrip().startswith('#'):
        return None, None, None
    # Split into at most 3 parts: key, en, pt
    parts = re.split(r'(?<!\\),', s, maxsplit=2)
    if len(parts) < 3:
        return None, None, None
    return parts[0], parts[1], parts[2]


def join_repo_line(key: str, en: str, pt: str) -> str:
    """Join fields back into a repo CSV line, escaping commas in en/pt with backslashes."""
    def esc(v: str) -> str:
        v = v.replace('\r', ' ').replace('\n', ' ')
        # Escape commas only (file convention)
        return v.replace(',', '\\,')
    return f"{key},{esc(en)},{esc(pt)}"


def load_user_csv(path: str):
    """Load user CSV with header keys,en,pt_BR into dict key->(en, pt)."""
    data = {}
    with open(path, 'r', encoding='utf-8-sig', newline='') as f:
        reader = csv.DictReader(f)
        # Accept multiple possible headers variations
        # Normalize column names
        field_map = {name.lower(): name for name in reader.fieldnames or []}
        key_col = field_map.get('keys') or field_map.get('key') or 'keys'
        en_col = field_map.get('en') or 'en'
        pt_col = field_map.get('pt_br') or field_map.get('pt') or 'pt_br'
        for row in reader:
            key = (row.get(key_col) or '').strip()
            if not key:
                continue
            en = row.get(en_col) or ''
            pt = row.get(pt_col) or ''
            data[key] = (en, pt)
    return data


def backup_file(path: str) -> str:
    ts = datetime.now().strftime('%Y%m%d-%H%M%S')
    backup = f"{path}.{ts}.bak"
    shutil.copy2(path, backup)
    return backup


def main():
    ap = argparse.ArgumentParser(description='Merge Portuguese translations into localization/translations.csv')
    ap.add_argument('--source', required=True, help='Path to user CSV (keys,en,pt_BR)')
    ap.add_argument('--target', default=os.path.join('localization', 'translations.csv'), help='Path to repo translations.csv')
    ap.add_argument('--all', action='store_true', help='Merge all keys (default: only item_*)')
    args = ap.parse_args()

    # Load user data
    user_data = load_user_csv(args.source)
    if not user_data:
        print('ERROR: No rows found in source CSV or unrecognized header (expected keys,en,pt_BR)')
        return 2

    # Load target file
    if not os.path.exists(args.target):
        print(f'ERROR: Target file not found: {args.target}')
        return 2

    with open(args.target, 'r', encoding='utf-8') as f:
        lines = f.read().splitlines()

    # Build index of existing keys
    index = {}
    for i, line in enumerate(lines):
        key, en, pt = split_repo_line(line)
        if key is None:
            continue
        index[key] = (i, en, pt)

    # Optional cleanup: remove bad key line entirely
    removed_bad_key = False
    bad_key = 'item_wooden_bow.item_name'
    if bad_key in index:
        i, _, _ = index[bad_key]
        # Replace the line with a comment noting removal
        lines[i] = f"# REMOVED malformed key: {bad_key} (replaced by item_wooden_bow_name)"
        removed_bad_key = True

    # Perform updates
    updates = 0
    skipped_empty = 0
    scope = 'all' if args.all else 'items-only'
    for key, (_en_src, pt_src) in user_data.items():
        if not args.all and not key.startswith('item_'):
            continue
        if not pt_src or not pt_src.strip():
            skipped_empty += 1
            continue
        if key not in index:
            # We don't add new keys here; only update existing ones
            continue
        i, en_dst, pt_dst = index[key]
        # Update PT value
        if pt_src != pt_dst:
            lines[i] = join_repo_line(key, en_dst, pt_src)
            updates += 1

    if updates == 0 and not removed_bad_key:
        print(f'No updates applied (scope={scope}). Nothing to do.')
        return 0

    # Backup original and write
    backup = backup_file(args.target)
    with open(args.target, 'w', encoding='utf-8', newline='') as f:
        f.write("\n".join(lines) + "\n")

    print('Merge complete:')
    print(f'  Target: {args.target}')
    print(f'  Backup: {backup}')
    print(f'  Scope:  {scope}')
    print(f'  Updated keys: {updates}')
    if removed_bad_key:
        print(f'  Removed malformed key: {bad_key}')
    print(f'  Skipped empty values: {skipped_empty}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
