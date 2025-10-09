#!/usr/bin/env python3
"""
Creates missing item files that are referenced in recipes but don't exist.
Also updates items_index.tres to register them.
"""

import re
from pathlib import Path
from datetime import datetime


# List of missing items from validation report
MISSING_ITEMS = {
    # Materials/Crafted outputs
    'berry_juice': {'name': 'Berry Juice', 'desc': 'A sweet, revitalizing drink squeezed from wild berries, restoring a bit of strength to weary adventurers.', 'folder': 'materials', 'tags': ['consumable', 'drink', 't1'], 'price': 8},
    'ironwood_planks': {'name': 'Ironwood Planks', 'desc': 'Heavy, durable planks from ironwood trees. Exceptional for construction.', 'folder': 'materials', 'tags': ['wood', 'construction', 't4'], 'price': 40},
    'medicinal_tincture': {'name': 'Medicinal Tincture', 'desc': 'Concentrated herbal medicine. Treats ailments and poisons.', 'folder': 'materials', 'tags': ['medicine', 'alchemy', 't3'], 'price': 25},
    'stone_block': {'name': 'Stone Block', 'desc': 'Carved stone blocks for construction. Foundation of great structures.', 'folder': 'materials', 'tags': ['stone', 'construction', 't2'], 'price': 10},
    
    # Consumables/Crafted
    'antidote': {'name': 'Antidote', 'desc': 'Powerful remedy that neutralizes poisons and toxins.', 'folder': 'consumables', 'tags': ['medicine', 'combat', 't3'], 'price': 30},
    
    # Tools
    'construction_kit': {'name': 'Construction Kit', 'desc': 'Complete set of tools for building and repairs.', 'folder': 'tools', 'tags': ['tool', 'construction', 't3'], 'price': 50},
    
    # Luxury/Special
    'crown': {'name': 'Crown', 'desc': 'Ornate royal crown adorned with precious gems. Symbol of sovereignty.', 'folder': 'luxury', 'tags': ['luxury', 'endgame', 't6'], 'price': 1000},
    'decorative_statue': {'name': 'Decorative Statue', 'desc': 'Finely carved statue for decoration. Shows artistic skill.', 'folder': 'furniture', 'tags': ['decoration', 'art', 't4'], 'price': 120},
    'legendary_weapon': {'name': 'Legendary Weapon', 'desc': 'Masterwork weapon of incredible power. The stuff of legends.', 'folder': 'combat', 'tags': ['weapon', 'legendary', 'endgame', 't6'], 'price': 2000},
    'masters_satchel': {'name': "Master's Satchel", 'desc': 'Premium storage satchel with advanced organization. For master crafters.', 'folder': 'storage', 'tags': ['storage', 'bag', 't5'], 'price': 250},
    'master_satchel': {'name': "Master's Satchel", 'desc': 'Premium storage satchel with advanced organization. For master crafters.', 'folder': 'storage', 'tags': ['storage', 'bag', 't5'], 'price': 250},
    'masterwork_armor_set': {'name': 'Masterwork Armor Set', 'desc': 'Complete set of the finest armor. Ultimate protection.', 'folder': 'combat', 'tags': ['armor', 'set', 'endgame', 't6'], 'price': 1500},
    'memorial_plaque': {'name': 'Memorial Plaque', 'desc': 'Engraved plaque to commemorate important events or people.', 'folder': 'construction', 'tags': ['decoration', 'memorial', 't3'], 'price': 80},
    'ornate_jewelry': {'name': 'Ornate Jewelry', 'desc': 'Exquisite jewelry pieces with intricate designs. High value.', 'folder': 'luxury', 'tags': ['jewelry', 'luxury', 't5'], 'price': 400},
    'trophy_mount': {'name': 'Trophy Mount', 'desc': 'Mounted display for hunting trophies and rare creature parts.', 'folder': 'furniture', 'tags': ['decoration', 'trophy', 't4'], 'price': 150},
    
    # Construction
    'bridge_section': {'name': 'Bridge Section', 'desc': 'Modular bridge section for crossing rivers and canyons.', 'folder': 'construction', 'tags': ['construction', 'infrastructure', 't4'], 'price': 200},
    'guild_hall_section': {'name': 'Guild Hall Section', 'desc': 'Structural component for building guild halls.', 'folder': 'construction', 'tags': ['construction', 'guild', 't5'], 'price': 300},
    
    # Ultimate endgame items
    'ultimate_endgame_1': {'name': 'Philosopher\'s Stone', 'desc': 'Legendary artifact of ultimate transmutation. Turns base metals to gold.', 'folder': 'materials', 'tags': ['legendary', 'endgame', 't6'], 'price': 5000},
    'ultimate_endgame_2': {'name': 'Dragon Heart Core', 'desc': 'Pulsing heart of an ancient dragon. Raw magical power incarnate.', 'folder': 'materials', 'tags': ['legendary', 'endgame', 't6'], 'price': 5000},
    'ultimate_endgame_3': {'name': 'Celestial Forge', 'desc': 'Divine forge that channels starlight. Creates artifacts of legend.', 'folder': 'guild', 'tags': ['legendary', 'endgame', 'station', 't6'], 'price': 10000},
    'ultimate_endgame_4': {'name': 'World Tree Sapling', 'desc': 'Young sapling of the mythical World Tree. Will grow to touch the heavens.', 'folder': 'materials', 'tags': ['legendary', 'endgame', 't6'], 'price': 5000},
    'ultimate_endgame_5': {'name': 'Titan\'s Crown', 'desc': 'Crown worn by the ancient titans. Grants dominion over the land.', 'folder': 'luxury', 'tags': ['legendary', 'endgame', 't6'], 'price': 10000},
    'ultimate_endgame_6': {'name': 'Eternal Flame Relic', 'desc': 'Relic containing an eternal flame that never dies. Ultimate power source.', 'folder': 'materials', 'tags': ['legendary', 'endgame', 't6'], 'price': 10000},
    
    # Winter/Seasonal
    'winter_coat': {'name': 'Winter Coat', 'desc': 'Thick, warm coat for harsh winter conditions. Essential for cold climates.', 'folder': 'luxury', 'tags': ['clothing', 'winter', 't4'], 'price': 80},
    
    # Premium workshop item
    'premium_workshop_tools': {'name': 'Premium Workshop Tools', 'desc': 'Highest quality workshop tools. For master artisans.', 'folder': 'tools', 'tags': ['tool', 'premium', 't5'], 'price': 200},
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
    stack_limit = 1 if 'weapon' in item_data['tags'] or 'armor' in item_data['tags'] else 99
    
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
    print("CREATE MISSING ITEMS SCRIPT")
    print("="*70)
    print()
    
    project_root = Path(__file__).parent
    items_dir = project_root / "source" / "common" / "gameplay" / "items"
    index_path = project_root / "source" / "common" / "registry" / "indexes" / "items_index.tres"
    
    print(f"Creating {len(MISSING_ITEMS)} missing items...")
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
    print("Next step: Run validation again to verify all issues are resolved!")


if __name__ == "__main__":
    main()

