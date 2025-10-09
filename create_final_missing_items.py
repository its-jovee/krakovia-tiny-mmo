#!/usr/bin/env python3
"""
Creates the final batch of missing items.
"""

import re
from pathlib import Path


# Final missing items
MISSING_ITEMS = {
    # Ultimate endgame outputs
    'grand_monument': {'name': 'Grand Monument', 'desc': 'Monumental structure celebrating great achievements. A wonder of the world.', 'folder': 'construction', 'tags': ['monument', 'endgame', 't6'], 'price': 10000},
    'master_trading_caravan': {'name': 'Master Trading Caravan', 'desc': 'Fully equipped trading caravan. Opens new trade routes and opportunities.', 'folder': 'tools', 'tags': ['trading', 'endgame', 't6'], 'price': 8000},
    'legendary_siege_engine': {'name': 'Legendary Siege Engine', 'desc': 'Devastating siege weapon of incredible power. Can break any fortification.', 'folder': 'combat', 'tags': ['siege', 'weapon', 'endgame', 't6'], 'price': 12000},
    'miracle_elixir': {'name': 'Miracle Elixir', 'desc': 'Ultimate alchemical creation. Grants miraculous healing and regeneration.', 'folder': 'consumables', 'tags': ['potion', 'miracle', 'endgame', 't6'], 'price': 5000},
    'champions_trophy': {'name': "Champion's Trophy", 'desc': 'Prestigious trophy awarded to true champions. Symbol of ultimate victory.', 'folder': 'luxury', 'tags': ['trophy', 'achievement', 'endgame', 't6'], 'price': 15000},
    'eternal_flame_brazier': {'name': 'Eternal Flame Brazier', 'desc': 'Brazier containing an eternal flame. Never needs fuel, lights the darkest nights.', 'folder': 'furniture', 'tags': ['light', 'eternal', 'endgame', 't6'], 'price': 7000},
    
    # Trapper items
    'bait': {'name': 'Bait', 'desc': 'Basic bait for trapping small game. Essential for trappers.', 'folder': 'materials', 'tags': ['bait', 'trapper', 't1'], 'price': 5},
    'better_bait': {'name': 'Better Bait', 'desc': 'Improved bait with higher success rate. Attracts larger prey.', 'folder': 'materials', 'tags': ['bait', 'trapper', 't2'], 'price': 15},
    'binding_cord': {'name': 'Binding Cord', 'desc': 'Strong cord for binding and crafting. Essential material for many recipes.', 'folder': 'materials', 'tags': ['cord', 'material', 't1'], 'price': 8},
    'premium_bait': {'name': 'Premium Bait', 'desc': 'Highest quality bait. Attracts even the rarest creatures.', 'folder': 'materials', 'tags': ['bait', 'trapper', 't3'], 'price': 30},
}


ITEM_TEMPLATE = """[gd_resource type="Resource" script_class="MaterialItem" load_steps=3 format=3 uid="uid://auto{uid}"]

[ext_resource type="Texture2D" uid="uid://budvautc5sw4b" path="res://assets/Raven Fantasy Icons/Separated Files/32x32/fb202.png" id="1_icon"]
[ext_resource type="Script" uid="uid://nsr1timk430j" path="res://source/common/gameplay/items/material_item.gd" id="2_material"]

[resource]
script = ExtResource("2_material")
item_name = &"{name}"
item_icon = ExtResource("1_icon")
description = "{description}"
can_trade = true
can_sell = true
minimum_price = {price}
stack_limit = {stack_limit}
tags = {tags}
metadata/_custom_type_script = "uid://nsr1timk430j"
"""


def generate_uid(slug):
    """Generate a simple UID based on slug"""
    return slug.replace('_', '')[:12]


def create_item_file(slug, item_data, items_dir):
    """Create a .tres file for an item"""
    folder = items_dir / item_data['folder']
    folder.mkdir(exist_ok=True)
    
    file_path = folder / f"{slug}.tres"
    
    # Don't overwrite existing files
    if file_path.exists():
        print(f"  SKIP: {slug} (already exists)")
        return None
    
    # Determine stack limit based on tags
    stack_limit = 1 if 'weapon' in item_data['tags'] or 'armor' in item_data['tags'] or 'siege' in item_data['tags'] else 99
    
    # Format tags for GDScript
    tags_str = str(item_data['tags']).replace("'", '"')
    
    content = ITEM_TEMPLATE.format(
        uid=generate_uid(slug),
        name=item_data['name'],
        description=item_data['desc'],
        price=item_data['price'],
        stack_limit=stack_limit,
        tags=tags_str
    )
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    rel_path = file_path.relative_to(items_dir.parent.parent.parent.parent)
    return {
        'slug': slug,
        'path': f"res://{str(rel_path).replace(chr(92), '/')}"
    }


def update_items_index(index_path, new_items):
    """Add new items to items_index.tres"""
    with open(index_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find the next_id
    match = re.search(r'next_id = (\d+)', content)
    if not match:
        print("ERROR: Could not find next_id in items_index.tres")
        return False
    
    next_id = int(match.group(1))
    
    # Find the entries array end
    entries_match = re.search(r'(entries = Array\[Dictionary\]\(\[.*?)(\]\))', content, re.DOTALL)
    if not entries_match:
        print("ERROR: Could not find entries array in items_index.tres")
        return False
    
    # Generate new entries
    new_entries = []
    for item in new_items:
        entry = f'''{{
&"hash": "",
&"id": {next_id},
&"path": "{item['path']}",
&"slug": &"{item['slug']}"
}}'''
        new_entries.append(entry)
        next_id += 1
    
    # Insert new entries before the closing ]
    entries_start = entries_match.group(1)
    entries_end = entries_match.group(2)
    
    # Add comma to last existing entry if needed
    if not entries_start.rstrip().endswith(','):
        entries_start = entries_start.rstrip() + ','
    
    new_entries_str = ', '.join(new_entries)
    new_content = content.replace(
        entries_match.group(0),
        f"{entries_start} {new_entries_str}{entries_end}"
    )
    
    # Update next_id
    new_content = re.sub(r'next_id = \d+', f'next_id = {next_id}', new_content)
    
    # Update version (timestamp)
    import time
    new_version = int(time.time())
    new_content = re.sub(r'version = \d+', f'version = {new_version}', new_content)
    
    with open(index_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    return True


def main():
    print("="*70)
    print("CREATE FINAL MISSING ITEMS")
    print("="*70)
    print()
    
    project_root = Path(__file__).parent
    items_dir = project_root / "source" / "common" / "gameplay" / "items"
    index_path = project_root / "source" / "common" / "registry" / "indexes" / "items_index.tres"
    
    print(f"Creating {len(MISSING_ITEMS)} final missing items...")
    print()
    
    created_items = []
    
    for slug, item_data in MISSING_ITEMS.items():
        result = create_item_file(slug, item_data, items_dir)
        if result:
            created_items.append(result)
            print(f"  OK Created: {slug} -> {item_data['folder']}/{slug}.tres")
    
    print()
    print(f"Created {len(created_items)} new item files")
    print()
    
    if created_items:
        print("Updating items_index.tres...")
        if update_items_index(index_path, created_items):
            print(f"OK Registered {len(created_items)} items in items_index.tres")
        else:
            print("ERROR Failed to update items_index.tres")
    
    print()
    print("="*70)
    print("DONE!")
    print("="*70)
    print()
    print(f"Created {len(created_items)} items")
    print()
    print("Final validation coming up!")


if __name__ == "__main__":
    main()

