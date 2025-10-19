#!/usr/bin/env python3
"""
Generate item translation entries from .tres files.
Extracts item_name and description from all item resources and creates CSV entries.
"""

import re
import os
from pathlib import Path


def parse_tres_file(file_path):
    """Parse a .tres file and extract item_name and description."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Extract item_name (can be StringName with & prefix)
        item_name_match = re.search(r'item_name\s*=\s*&?"([^"]+)"', content)
        item_name = item_name_match.group(1) if item_name_match else None
        
        # Extract description - match quoted string ending before next property
        desc_match = re.search(r'description\s*=\s*"([^"]*)"', content)
        description = desc_match.group(1) if desc_match else ""
        
        # Clean up description (remove extra whitespace, newlines, escape sequences)
        description = ' '.join(description.split())
        description = description.strip()
        
        return item_name, description
    except Exception as e:
        print(f"Error parsing {file_path}: {e}")
        return None, None


def slug_from_filename(file_path):
    """Get slug (filename without extension) from file path."""
    return Path(file_path).stem


def generate_translation_key(slug, field):
    """Generate translation key from slug and field name."""
    # Convert slug to snake_case if needed and add prefix
    return f"item_{slug}_{field}"


def main():
    # Get project root (script is in tools/ directory)
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    items_dir = project_root / "source" / "common" / "gameplay" / "items"
    
    print("="*60)
    print("ITEM TRANSLATION GENERATOR")
    print("="*60)
    print()
    
    if not items_dir.exists():
        print(f"Error: Items directory not found: {items_dir}")
        return
    
    # Collect all .tres files
    tres_files = list(items_dir.rglob("*.tres"))
    print(f"Found {len(tres_files)} item files")
    print()
    
    # Parse all items
    items = []
    skipped = []
    
    for tres_file in sorted(tres_files):
        slug = slug_from_filename(tres_file)
        item_name, description = parse_tres_file(tres_file)
        
        if item_name:
            items.append({
                'slug': slug,
                'name': item_name,
                'description': description,
                'path': str(tres_file.relative_to(project_root))
            })
        else:
            skipped.append(str(tres_file.relative_to(project_root)))
    
    print(f"Successfully parsed: {len(items)} items")
    if skipped:
        print(f"Skipped (no item_name): {len(skipped)} items")
        for skip in skipped[:5]:  # Show first 5
            print(f"  - {skip}")
        if len(skipped) > 5:
            print(f"  ... and {len(skipped) - 5} more")
    print()
    
    # Generate CSV entries
    output_file = project_root / "tools" / "item_translations_generated.csv"
    
    with open(output_file, 'w', encoding='utf-8') as f:
        # Write header
        f.write("# Generated Item Translations\n")
        f.write("# Format: key,English,Portuguese\n")
        f.write("# Total items: " + str(len(items)) + "\n")
        f.write("#\n")
        f.write("# NOTE: Portuguese translations need to be filled in manually\n")
        f.write("# Copy these lines to localization/translations.csv and translate the third column\n")
        f.write("\n")
        
        # Group by category (from path)
        items_by_category = {}
        for item in items:
            category = Path(item['path']).parent.name
            if category not in items_by_category:
                items_by_category[category] = []
            items_by_category[category].append(item)
        
        # Write items by category
        for category in sorted(items_by_category.keys()):
            f.write(f"\n# {category.upper()} Items\n")
            category_items = items_by_category[category]
            
            for item in sorted(category_items, key=lambda x: x['slug']):
                # Item name
                name_key = generate_translation_key(item['slug'], 'name')
                f.write(f'{name_key},{item["name"]},{item["name"]}\n')
                
                # Item description (if exists)
                if item['description']:
                    desc_key = generate_translation_key(item['slug'], 'desc')
                    # Escape commas in description
                    desc_escaped = item['description'].replace(',', '\\,')
                    f.write(f'{desc_key},{desc_escaped},{desc_escaped}\n')
    
    print(f"✅ Generated translation file: {output_file}")
    print()
    print("Next steps:")
    print("1. Review the generated file")
    print("2. Translate the Portuguese column (third column)")
    print("3. Copy entries to localization/translations.csv")
    print("4. Update item display code to use TranslationServer")
    print()
    
    # Generate statistics
    print("Statistics:")
    print(f"  Total items: {len(items)}")
    print(f"  Items with descriptions: {sum(1 for i in items if i['description'])}")
    print(f"  Items without descriptions: {sum(1 for i in items if not i['description'])}")
    print(f"  Total translation strings: {len(items) + sum(1 for i in items if i['description'])}")
    print()
    
    # Show sample entries
    print("Sample entries (first 5):")
    for item in items[:5]:
        print(f"  {item['slug']}: {item['name']}")
        if item['description']:
            desc_preview = item['description'][:60] + "..." if len(item['description']) > 60 else item['description']
            print(f"    → {desc_preview}")
    
    print()
    print("="*60)


if __name__ == "__main__":
    main()
