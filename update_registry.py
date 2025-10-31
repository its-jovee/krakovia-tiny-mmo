#!/usr/bin/env python3
"""
Scans filesystem for items and recipes, validates them, and updates registries
to include any missing valid entries.
"""

import re
import time
from pathlib import Path
from datetime import datetime
from collections import defaultdict
import hashlib


class TresParser:
    """Parser for Godot .tres files"""
    
    @staticmethod
    def parse_value(value_str):
        """Parse a GDScript value to Python"""
        value_str = value_str.strip()
        
        # Handle StringName
        if value_str.startswith('&"') and value_str.endswith('"'):
            return value_str[2:-1]
        
        # Handle empty StringName
        if value_str == '&""':
            return ""
        
        # Handle numbers
        try:
            if '.' in value_str:
                return float(value_str)
            return int(value_str)
        except ValueError:
            pass
        
        # Handle strings
        if value_str.startswith('"') and value_str.endswith('"'):
            return value_str[1:-1]
        
        # Handle null
        if value_str == 'null':
            return None
        
        return value_str
    
    @staticmethod
    def parse_item(file_path):
        """Parse and validate an item .tres file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Check script_class exists
            script_match = re.search(r'script_class\s*=\s*"([^"]+)"', content)
            if not script_match:
                return None  # Invalid item file
            
            script_class = script_match.group(1)
            
            # Must be an Item subclass
            if 'Item' not in script_class and script_class not in ['MaterialItem', 'WeaponItem', 'ConsumableItem', 'GearItem']:
                return None
            
            item = {
                'script_class': script_class,
                'valid': True,
                'errors': []
            }
            
            # Parse required fields
            patterns = {
                'item_name': r'item_name\s*=\s*(.+)',
                'description': r'description\s*=\s*"([^"]*)"',
                'can_trade': r'can_trade\s*=\s*(\w+)',
                'can_sell': r'can_sell\s*=\s*(\w+)',
                'minimum_price': r'minimum_price\s*=\s*(\d+)',
                'stack_limit': r'stack_limit\s*=\s*(\d+)',
            }
            
            for key, pattern in patterns.items():
                match = re.search(pattern, content)
                if match:
                    if key in ['can_trade', 'can_sell']:
                        item[key] = match.group(1).lower() == 'true'
                    else:
                        item[key] = TresParser.parse_value(match.group(1))
                else:
                    item['valid'] = False
                    item['errors'].append(f"Missing {key}")
            
            # Check for item_icon (can be ExtResource or null)
            icon_match = re.search(r'item_icon\s*=\s*(ExtResource\([^)]+\)|null)', content)
            if not icon_match:
                item['valid'] = False
                item['errors'].append("Missing item_icon")
            else:
                item['has_icon'] = icon_match.group(1) != 'null'
            
            # Parse tags
            tags_match = re.search(r'tags\s*=\s*\[([^\]]*)\]', content)
            if tags_match:
                tags_str = tags_match.group(1)
                item['tags'] = [t.strip().strip('"') for t in tags_str.split(',') if t.strip()]
            else:
                item['tags'] = []
            
            return item
        except Exception as e:
            return {'valid': False, 'errors': [f"Parse error: {str(e)}"]}
    
    @staticmethod
    def parse_recipe(file_path):
        """Parse and validate a recipe .tres file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Check script_class
            script_match = re.search(r'script_class\s*=\s*"([^"]+)"', content)
            if not script_match or script_match.group(1) != 'CraftingRecipe':
                return None  # Not a recipe file
            
            recipe = {
                'valid': True,
                'errors': []
            }
            
            # Parse required fields
            patterns = {
                'slug': r'slug\s*=\s*(.+)',
                'recipe_name': r'recipe_name\s*=\s*(.+)',
                'description': r'description\s*=\s*"([^"]*)"',
                'required_class': r'required_class\s*=\s*"([^"]*)"',
                'required_level': r'required_level\s*=\s*(\d+)',
                'gold_cost': r'gold_cost\s*=\s*(\d+)',
                'energy_cost': r'energy_cost\s*=\s*([0-9.]+)',
                'output_1_slug': r'output_1_slug\s*=\s*(.+)',
            }
            
            valid_classes = ['miner', 'forager', 'trapper', 'blacksmith', 'culinarian', 'artisan']
            
            for key, pattern in patterns.items():
                match = re.search(pattern, content)
                if match:
                    value = TresParser.parse_value(match.group(1))
                    
                    # Validate required_class
                    if key == 'required_class':
                        if value not in valid_classes:
                            recipe['valid'] = False
                            recipe['errors'].append(f"Invalid required_class: {value}")
                        else:
                            recipe[key] = value
                    # Validate required_level
                    elif key == 'required_level':
                        if not isinstance(value, int) or value < 1:
                            recipe['valid'] = False
                            recipe['errors'].append(f"Invalid required_level: {value}")
                        else:
                            recipe[key] = value
                    else:
                        recipe[key] = value
                else:
                    recipe['valid'] = False
                    recipe['errors'].append(f"Missing {key}")
            
            # Check output_1_slug is not empty
            if recipe.get('output_1_slug') == '' or recipe.get('output_1_slug') is None:
                recipe['valid'] = False
                recipe['errors'].append("output_1_slug is empty")
            
            # Parse optional inputs/outputs
            for i in range(1, 5):
                input_slug_match = re.search(rf'input_{i}_slug\s*=\s*(.+)', content)
                input_qty_match = re.search(rf'input_{i}_quantity\s*=\s*(\d+)', content)
                if input_slug_match:
                    recipe[f'input_{i}_slug'] = TresParser.parse_value(input_slug_match.group(1))
                    if input_qty_match:
                        recipe[f'input_{i}_quantity'] = int(input_qty_match.group(1))
                    else:
                        recipe[f'input_{i}_quantity'] = 0
            
            for i in range(1, 3):
                output_slug_match = re.search(rf'output_{i}_slug\s*=\s*(.+)', content)
                output_qty_match = re.search(rf'output_{i}_quantity\s*=\s*(\d+)', content)
                if output_slug_match:
                    recipe[f'output_{i}_slug'] = TresParser.parse_value(output_slug_match.group(1))
                    if output_qty_match:
                        recipe[f'output_{i}_quantity'] = int(output_qty_match.group(1))
                    else:
                        recipe[f'output_{i}_quantity'] = 0
            
            # Parse tags
            tags_match = re.search(r'tags\s*=\s*\[([^\]]*)\]', content)
            if tags_match:
                tags_str = tags_match.group(1)
                recipe['tags'] = [t.strip().strip('"') for t in tags_str.split(',') if t.strip()]
            else:
                recipe['tags'] = []
            
            return recipe
        except Exception as e:
            return {'valid': False, 'errors': [f"Parse error: {str(e)}"]}


def parse_index_file(index_path):
    """Parse items_index.tres or recipes_index.tres to extract registered entries"""
    registered = {}
    
    with open(index_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract entries
    pattern = r'&"id":\s*(\d+),\s*&"path":\s*"([^"]+)",\s*&"slug":\s*&"([^"]+)"'
    matches = re.findall(pattern, content)
    
    for entry_id, path, slug in matches:
        registered[slug] = {
            'id': int(entry_id),
            'path': path,
            'slug': slug
        }
    
    # Get next_id
    next_id_match = re.search(r'next_id\s*=\s*(\d+)', content)
    next_id = int(next_id_match.group(1)) if next_id_match else 0
    
    return registered, next_id


def scan_filesystem_items(project_root):
    """Scan filesystem for all item .tres files and validate them"""
    items_dir = project_root / "source" / "common" / "gameplay" / "items"
    
    found_items = {}
    item_dirs = [
        'materials', 'combat', 'consumables', 'construction', 'food',
        'furniture', 'gears', 'guild', 'household', 'luxury', 'storage', 'tools'
    ]
    
    for subdir in item_dirs:
        subdir_path = items_dir / subdir
        if not subdir_path.exists():
            continue
            
        for item_file in subdir_path.glob("*.tres"):
            # Skip item_slot files
            if 'item_slot' in str(item_file):
                continue
            
            slug = item_file.stem
            # Handle weapon.item.tres files
            if slug.endswith('.item'):
                slug = slug.replace('.item', '')
            
            # Parse and validate item
            item_data = TresParser.parse_item(item_file)
            
            if item_data is None:
                continue  # Not a valid item file
            
            # Get relative path
            rel_path = item_file.relative_to(project_root)
            res_path = f"res://{str(rel_path).replace(chr(92), '/')}"
            
            found_items[slug] = {
                'slug': slug,
                'path': res_path,
                'file_path': str(item_file),
                'subdir': subdir,
                'valid': item_data.get('valid', False),
                'errors': item_data.get('errors', [])
            }
    
    return found_items


def scan_filesystem_recipes(project_root):
    """Scan filesystem for all recipe .tres files and validate them"""
    recipes_dir = project_root / "source" / "common" / "gameplay" / "crafting" / "recipes"
    
    found_recipes = {}
    
    for recipe_file in recipes_dir.rglob("*.tres"):
        # Parse and validate recipe first to get the slug from inside the file
        recipe_data = TresParser.parse_recipe(recipe_file)
        
        if recipe_data is None:
            continue  # Not a recipe file
        
        # Use the slug from inside the recipe file, not the filename
        slug = recipe_data.get('slug', '')
        if not slug:
            # Fallback to filename if slug is missing (shouldn't happen for valid recipes)
            slug = recipe_file.stem
        
        # Get relative path
        rel_path = recipe_file.relative_to(project_root)
        res_path = f"res://{str(rel_path).replace(chr(92), '/')}"
        
        # Get class name from parent directory
        class_name = recipe_file.parent.name
        
        found_recipes[slug] = {
            'slug': slug,
            'path': res_path,
            'file_path': str(recipe_file),
            'class': class_name,
            'valid': recipe_data.get('valid', False),
            'errors': recipe_data.get('errors', []),
            'required_class': recipe_data.get('required_class', ''),
            'required_level': recipe_data.get('required_level', 0)
        }
    
    return found_recipes


def generate_hash(slug):
    """Generate a hash for registry entry"""
    return hashlib.sha256(slug.encode()).hexdigest()


def update_items_index(index_path, new_items):
    """Update items_index.tres with new valid items"""
    with open(index_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Get current next_id
    next_id_match = re.search(r'next_id\s*=\s*(\d+)', content)
    if not next_id_match:
        print("ERROR: Could not find next_id in items_index.tres")
        return False
    
    next_id = int(next_id_match.group(1))
    
    # Find the entries array end
    entries_match = re.search(r'(entries\s*=\s*Array\[Dictionary\]\(\[.*?)(\]\))', content, re.DOTALL)
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
    if not entries_start.rstrip().endswith(',') and not entries_start.rstrip().endswith('['):
        entries_start = entries_start.rstrip() + ','
    
    new_entries_str = ', '.join(new_entries)
    new_content = content.replace(
        entries_match.group(0),
        f"{entries_start} {new_entries_str}{entries_end}"
    )
    
    # Update next_id
    new_content = re.sub(r'next_id\s*=\s*\d+', f'next_id = {next_id}', new_content)
    
    # Update version (timestamp)
    new_version = int(time.time())
    new_content = re.sub(r'version\s*=\s*\d+', f'version = {new_version}', new_content)
    
    with open(index_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(new_content)
    
    return True


def update_recipes_index(index_path, new_recipes):
    """Update recipes_index.tres with new valid recipes"""
    with open(index_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Get current next_id
    next_id_match = re.search(r'next_id\s*=\s*(\d+)', content)
    if not next_id_match:
        print("ERROR: Could not find next_id in recipes_index.tres")
        return False
    
    next_id = int(next_id_match.group(1))
    
    # Find the entries array end
    entries_match = re.search(r'(entries\s*=\s*Array\[Dictionary\]\(\[.*?)(\]\))', content, re.DOTALL)
    if not entries_match:
        print("ERROR: Could not find entries array in recipes_index.tres")
        return False
    
    # Generate new entries
    new_entries = []
    for recipe in new_recipes:
        hash_val = generate_hash(recipe['slug'])
        entry = f'''{{
&"hash": "{hash_val}",
&"id": {next_id},
&"path": "{recipe['path']}",
&"slug": &"{recipe['slug']}"
}}'''
        new_entries.append(entry)
        next_id += 1
    
    # Insert new entries before the closing ]
    entries_start = entries_match.group(1)
    entries_end = entries_match.group(2)
    
    # Add comma to last existing entry if needed
    if not entries_start.rstrip().endswith(',') and not entries_start.rstrip().endswith('['):
        entries_start = entries_start.rstrip() + ','
    
    new_entries_str = ', '.join(new_entries)
    new_content = content.replace(
        entries_match.group(0),
        f"{entries_start} {new_entries_str}{entries_end}"
    )
    
    # Update next_id
    new_content = re.sub(r'next_id\s*=\s*\d+', f'next_id = {next_id}', new_content)
    
    # Update version (timestamp)
    new_version = int(time.time())
    new_content = re.sub(r'version\s*=\s*\d+', f'version = {new_version}', new_content)
    
    with open(index_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(new_content)
    
    return True


def main():
    project_root = Path(__file__).parent
    
    print("="*70)
    print("REGISTRY UPDATE SCRIPT")
    print("="*70)
    print()
    
    # Load registries
    items_index_path = project_root / "source" / "common" / "registry" / "indexes" / "items_index.tres"
    recipes_index_path = project_root / "source" / "common" / "registry" / "indexes" / "recipes_index.tres"
    
    print("Loading registries...")
    registered_items, items_next_id = parse_index_file(items_index_path)
    registered_recipes, recipes_next_id = parse_index_file(recipes_index_path)
    print(f"  Items in registry: {len(registered_items)}")
    print(f"  Recipes in registry: {len(registered_recipes)}")
    print()
    
    # Scan filesystem
    print("Scanning filesystem for items...")
    found_items = scan_filesystem_items(project_root)
    print(f"  Found {len(found_items)} item files")
    
    print("Scanning filesystem for recipes...")
    found_recipes = scan_filesystem_recipes(project_root)
    print(f"  Found {len(found_recipes)} recipe files")
    print()
    
    # Find missing and valid items
    print("Validating items...")
    missing_valid_items = []
    invalid_items = []
    
    for slug, item_data in found_items.items():
        if slug not in registered_items:
            if item_data['valid']:
                missing_valid_items.append(item_data)
            else:
                invalid_items.append(item_data)
    
    print(f"  Missing valid items: {len(missing_valid_items)}")
    print(f"  Invalid items (not added): {len(invalid_items)}")
    if invalid_items:
        print("  Invalid items:")
        for item in invalid_items[:5]:
            print(f"    - {item['slug']}: {', '.join(item['errors'])}")
        if len(invalid_items) > 5:
            print(f"    ... and {len(invalid_items) - 5} more")
    print()
    
    # Find missing and valid recipes
    print("Validating recipes...")
    missing_valid_recipes = []
    invalid_recipes = []
    duplicate_slugs = defaultdict(list)
    
    # Check for duplicate slugs in filesystem
    for slug, recipe_data in found_recipes.items():
        duplicate_slugs[slug].append(recipe_data)
    
    # Warn about duplicates
    for slug, recipes in duplicate_slugs.items():
        if len(recipes) > 1:
            print(f"  WARNING: Duplicate slug '{slug}' found in {len(recipes)} files:")
            for recipe in recipes:
                print(f"    - {recipe['file_path']}")
    
    for slug, recipe_data in found_recipes.items():
        # Skip if duplicate slug (only add the first one)
        if len(duplicate_slugs[slug]) > 1 and recipe_data != duplicate_slugs[slug][0]:
            print(f"  SKIPPING {recipe_data['file_path']}: duplicate slug '{slug}'")
            continue
            
        if slug not in registered_recipes:
            if recipe_data['valid']:
                missing_valid_recipes.append(recipe_data)
            else:
                invalid_recipes.append(recipe_data)
    
    print(f"  Missing valid recipes: {len(missing_valid_recipes)}")
    print(f"  Invalid recipes (not added): {len(invalid_recipes)}")
    if invalid_recipes:
        print("  Invalid recipes:")
        for recipe in invalid_recipes[:5]:
            print(f"    - {recipe['slug']}: {', '.join(recipe['errors'])}")
        if len(invalid_recipes) > 5:
            print(f"    ... and {len(invalid_recipes) - 5} more")
    print()
    
    # Update registries
    if missing_valid_items:
        print(f"Updating items_index.tres with {len(missing_valid_items)} new items...")
        if update_items_index(items_index_path, missing_valid_items):
            print("  ✓ Items registry updated successfully")
        else:
            print("  ✗ Failed to update items registry")
        print()
    
    if missing_valid_recipes:
        print(f"Updating recipes_index.tres with {len(missing_valid_recipes)} new recipes...")
        if update_recipes_index(recipes_index_path, missing_valid_recipes):
            print("  ✓ Recipes registry updated successfully")
        else:
            print("  ✗ Failed to update recipes registry")
        print()
    
    # Summary
    print("="*70)
    print("SUMMARY")
    print("="*70)
    print(f"Items added to registry: {len(missing_valid_items)}")
    print(f"Recipes added to registry: {len(missing_valid_recipes)}")
    print(f"Invalid items skipped: {len(invalid_items)}")
    print(f"Invalid recipes skipped: {len(invalid_recipes)}")
    print("="*70)


if __name__ == "__main__":
    main()

