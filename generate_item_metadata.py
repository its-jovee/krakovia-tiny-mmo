#!/usr/bin/env python3
"""
Generate item metadata from loot tables and crafting recipes.
Creates a JSON lookup table for tooltips showing harvest sources and crafting recipes.
"""

import os
import json
import re
from pathlib import Path
from collections import defaultdict


def parse_tres_file(filepath):
    """Parse a .tres resource file and extract relevant data."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    return content


def extract_loot_entries(tres_content):
    """Extract loot entries from a HarvestLootTable .tres file."""
    items = []
    
    # Find loot_entries array
    loot_match = re.search(r'loot_entries = Array\[Dictionary\]\(\[(.*?)\]\)', tres_content, re.DOTALL)
    if loot_match:
        entries_text = loot_match.group(1)
        # Split by dictionary boundaries
        dict_pattern = r'\{([^}]+)\}'
        for match in re.finditer(dict_pattern, entries_text):
            entry_text = match.group(1)
            # Extract item_slug
            slug_match = re.search(r'"item_slug":\s*&"([^"]+)"', entry_text)
            if slug_match:
                items.append({'slug': slug_match.group(1), 'is_rare': False})
    
    # Find rare_bonus_entries array
    rare_match = re.search(r'rare_bonus_entries = Array\[Dictionary\]\(\[(.*?)\]\)', tres_content, re.DOTALL)
    if rare_match:
        entries_text = rare_match.group(1)
        dict_pattern = r'\{([^}]+)\}'
        for match in re.finditer(dict_pattern, entries_text):
            entry_text = match.group(1)
            slug_match = re.search(r'"item_slug":\s*&"([^"]+)"', entry_text)
            if slug_match:
                items.append({'slug': slug_match.group(1), 'is_rare': True})
    
    return items


def parse_loot_tables(loot_tables_dir):
    """Parse all loot tables and create harvest sources mapping."""
    harvest_sources = defaultdict(list)
    
    for filepath in Path(loot_tables_dir).glob('*.tres'):
        filename = filepath.stem
        # Extract class and tier from filename (e.g., "miner_t1_loot_table")
        match = re.match(r'(\w+)_t(\d+)_loot_table', filename)
        if not match:
            continue
        
        class_name = match.group(1)
        tier = int(match.group(2))
        
        tres_content = parse_tres_file(filepath)
        items = extract_loot_entries(tres_content)
        
        for item in items:
            harvest_sources[item['slug']].append({
                'class': class_name,
                'tier': tier,
                'is_rare': item['is_rare']
            })
    
    return harvest_sources


def extract_recipe_data(tres_content, filename):
    """Extract recipe data from a CraftingRecipe .tres file."""
    recipe_data = {
        'recipe_name': filename.replace('_', ' ').title().replace('Recipe', '').strip(),
        'class': 'miner',  # default
        'level': 1,
        'slug': filename,
        'outputs': []
    }
    
    # Extract recipe name
    name_match = re.search(r'recipe_name = &?"([^"]+)"', tres_content)
    if name_match:
        recipe_data['recipe_name'] = name_match.group(1)
    
    # Extract required class
    class_match = re.search(r'required_class = "([^"]+)"', tres_content)
    if class_match:
        recipe_data['class'] = class_match.group(1)
    
    # Extract required level
    level_match = re.search(r'required_level = (\d+)', tres_content)
    if level_match:
        recipe_data['level'] = int(level_match.group(1))
    
    # Extract slug
    slug_match = re.search(r'slug = &?"([^"]+)"', tres_content)
    if slug_match:
        recipe_data['slug'] = slug_match.group(1)
    
    # Extract output items
    output_match = re.search(r'output_1_slug = &?"([^"]+)"', tres_content)
    if output_match and output_match.group(1):
        recipe_data['outputs'].append(output_match.group(1))
    
    output2_match = re.search(r'output_2_slug = &?"([^"]+)"', tres_content)
    if output2_match and output2_match.group(1):
        recipe_data['outputs'].append(output2_match.group(1))
    
    return recipe_data


def parse_recipes(recipes_dir):
    """Parse all recipes and create crafted_by mapping."""
    crafted_by = defaultdict(list)
    
    for filepath in Path(recipes_dir).rglob('*.tres'):
        tres_content = parse_tres_file(filepath)
        
        # Skip if not a CraftingRecipe
        if 'script_class="CraftingRecipe"' not in tres_content and 'CraftingRecipe' not in tres_content:
            continue
        
        recipe_data = extract_recipe_data(tres_content, filepath.stem)
        
        # Add recipe to each output item
        for output_slug in recipe_data['outputs']:
            if output_slug:  # Skip empty slugs
                crafted_by[output_slug].append({
                    'recipe_name': recipe_data['recipe_name'],
                    'class': recipe_data['class'],
                    'level': recipe_data['level'],
                    'slug': recipe_data['slug']
                })
    
    return crafted_by


def generate_item_metadata():
    """Generate complete item metadata JSON."""
    project_root = Path(__file__).parent
    loot_tables_dir = project_root / 'source' / 'server' / 'world' / 'components' / 'harvesting' / 'loot_tables'
    recipes_dir = project_root / 'source' / 'common' / 'gameplay' / 'crafting' / 'recipes'
    output_file = project_root / 'source' / 'common' / 'gameplay' / 'items' / 'item_metadata.json'
    
    print("Parsing loot tables...")
    harvest_sources = parse_loot_tables(loot_tables_dir)
    print(f"Found {len(harvest_sources)} items with harvest sources")
    
    print("Parsing recipes...")
    crafted_by = parse_recipes(recipes_dir)
    print(f"Found {len(crafted_by)} items that can be crafted")
    
    # Combine all items
    all_items = set(harvest_sources.keys()) | set(crafted_by.keys())
    
    metadata = {}
    for item_slug in sorted(all_items):
        metadata[item_slug] = {
            'harvest_sources': harvest_sources.get(item_slug, []),
            'crafted_by': crafted_by.get(item_slug, [])
        }
    
    # Write output
    output_file.parent.mkdir(parents=True, exist_ok=True)
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)
    
    print(f"\nGenerated metadata for {len(metadata)} items")
    print(f"Output: {output_file}")
    
    # Print some statistics
    harvestable_count = sum(1 for item in metadata.values() if item['harvest_sources'])
    craftable_count = sum(1 for item in metadata.values() if item['crafted_by'])
    both_count = sum(1 for item in metadata.values() if item['harvest_sources'] and item['crafted_by'])
    
    print(f"\nStatistics:")
    print(f"  Harvestable only: {harvestable_count - both_count}")
    print(f"  Craftable only: {craftable_count - both_count}")
    print(f"  Both harvestable and craftable: {both_count}")


if __name__ == '__main__':
    generate_item_metadata()


