#!/usr/bin/env python3
"""
Economy Balance Validation Script
Checks that recipes and items are properly balanced after rebalancing
"""

import re
from pathlib import Path
from collections import defaultdict

PROJECT_ROOT = Path(__file__).parent

def parse_recipe(filepath):
    """Extract key fields from recipe"""
    content = filepath.read_text(encoding='utf-8')
    
    level_match = re.search(r'required_level = (\d+)', content)
    level = int(level_match.group(1)) if level_match else 1
    
    class_match = re.search(r'required_class = "([^"]+)"', content)
    class_name = class_match.group(1) if class_match else "unknown"
    
    name_match = re.search(r'recipe_name = &"([^"]+)"', content)
    name = name_match.group(1) if name_match else filepath.stem
    
    # Get input quantities
    inputs = []
    for i in range(1, 4):
        slug_match = re.search(f'input_{i}_slug = &"([^"]*)"', content)
        qty_match = re.search(f'input_{i}_quantity = (\d+)', content)
        if slug_match and slug_match.group(1):
            qty = int(qty_match.group(1)) if qty_match else 1
            inputs.append((slug_match.group(1), qty))
    
    total_inputs = sum(qty for _, qty in inputs)
    
    return {
        'name': name,
        'level': level,
        'class': class_name,
        'inputs': inputs,
        'total_inputs': total_inputs,
        'folder': filepath.parent.name,
    }

def parse_item(filepath):
    """Extract key fields from item"""
    content = filepath.read_text(encoding='utf-8')
    
    name_match = re.search(r'item_name = &"([^"]+)"', content)
    name = name_match.group(1) if name_match else filepath.stem
    
    price_match = re.search(r'minimum_price = (\d+)', content)
    price = int(price_match.group(1)) if price_match else 0
    
    can_sell_match = re.search(r'can_sell = (true|false)', content)
    can_sell = can_sell_match.group(1) == 'true' if can_sell_match else False
    
    return {
        'name': name,
        'price': price,
        'can_sell': can_sell,
        'folder': filepath.parent.name,
    }

def main():
    print("=" * 70)
    print("ECONOMY BALANCE VALIDATION")
    print("=" * 70)
    
    recipes_dir = PROJECT_ROOT / "source" / "common" / "gameplay" / "crafting" / "recipes"
    items_dir = PROJECT_ROOT / "source" / "common" / "gameplay" / "items"
    
    # Scan recipes
    print("\n📋 Scanning Recipes...")
    recipes_by_level = defaultdict(list)
    recipes_by_class = defaultdict(list)
    all_recipes = []
    
    for recipe_file in recipes_dir.glob('**/*.tres'):
        try:
            recipe = parse_recipe(recipe_file)
            all_recipes.append(recipe)
            recipes_by_level[recipe['level']].append(recipe)
            recipes_by_class[recipe['class']].append(recipe)
        except Exception as e:
            print(f"  ⚠️  Error parsing {recipe_file.name}: {e}")
    
    print(f"  ✓ Found {len(all_recipes)} recipes")
    
    # Validate recipe distribution
    print("\n📊 Recipe Distribution:")
    print(f"{'Level':<8} {'Count':<8} {'Min Inputs':<12} {'Max Inputs':<12} {'Avg Inputs':<12}")
    print("-" * 60)
    
    issues = []
    
    for level in range(1, 31):
        recipes = recipes_by_level.get(level, [])
        if recipes:
            total_inputs = [r['total_inputs'] for r in recipes]
            min_inputs = min(total_inputs)
            max_inputs = max(total_inputs)
            avg_inputs = sum(total_inputs) / len(total_inputs)
            
            print(f"L{level:<7} {len(recipes):<8} {min_inputs:<12} {max_inputs:<12} {avg_inputs:<12.1f}")
            
            # Check for issues
            if level <= 10 and len(recipes) == 0:
                issues.append(f"Level {level}: No recipes assigned (should have 1)")
            elif level <= 10 and len(recipes) > 1:
                issues.append(f"Level {level}: {len(recipes)} recipes (should have only 1)")
        else:
            print(f"L{level:<7} {'0':<8} {'-':<12} {'-':<12} {'-':<12}")
            if level <= 10:
                issues.append(f"Level {level}: No recipes assigned")
    
    # Check class balance
    print("\n👥 Class Distribution:")
    for class_name in sorted(recipes_by_class.keys()):
        count = len(recipes_by_class[class_name])
        print(f"  {class_name:<15}: {count:>3} recipes")
    
    # Check interdependency
    interdependent_count = sum(1 for r in all_recipes if r['folder'] == 'interdependent')
    print(f"\n🔗 Interdependent recipes: {interdependent_count}")
    
    # Find first interdependent
    interdep_by_level = [(r['level'], r['name']) for r in all_recipes if r['folder'] == 'interdependent']
    interdep_by_level.sort()
    if interdep_by_level:
        first_level, first_name = interdep_by_level[0]
        print(f"  First interdependent at level {first_level}: {first_name}")
        if first_level > 3:
            issues.append(f"Interdependency starts too late (level {first_level}, should be 2-3)")
    
    # Scan items
    print("\n💰 Scanning Items...")
    items_by_folder = defaultdict(list)
    sellable_items = []
    
    for item_file in items_dir.glob('**/*.tres'):
        try:
            item = parse_item(item_file)
            items_by_folder[item['folder']].append(item)
            if item['can_sell'] and item['price'] > 0:
                sellable_items.append(item)
        except Exception as e:
            pass  # Skip parsing errors for items
    
    print(f"  ✓ Found {len(sellable_items)} sellable items")
    
    # Price distribution
    print("\n💵 Price Distribution:")
    price_ranges = [
        (0, 5, "Very Low"),
        (6, 15, "Low"),
        (16, 50, "Medium"),
        (51, 150, "High"),
        (151, 500, "Very High"),
        (501, 10000, "Legendary"),
    ]
    
    for min_p, max_p, label in price_ranges:
        count = sum(1 for item in sellable_items if min_p <= item['price'] <= max_p)
        if count > 0:
            print(f"  {label:<15} ({min_p:>3}-{max_p:>4}g): {count:>3} items")
    
    # Report issues
    print("\n" + "=" * 70)
    if issues:
        print("⚠️  ISSUES FOUND:")
        for issue in issues:
            print(f"  - {issue}")
    else:
        print("✅ NO MAJOR ISSUES FOUND")
    
    print("=" * 70)
    
    # Summary
    print("\n📈 Summary:")
    print(f"  Total Recipes: {len(all_recipes)}")
    print(f"  Level Range: {min(r['level'] for r in all_recipes)} - {max(r['level'] for r in all_recipes)}")
    print(f"  Sellable Items: {len(sellable_items)}")
    print(f"  Price Range: {min(i['price'] for i in sellable_items if i['price'] > 0)}g - {max(i['price'] for i in sellable_items)}g")
    
    print("\n✓ Validation complete!\n")

if __name__ == "__main__":
    main()

