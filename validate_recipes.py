#!/usr/bin/env python3
"""
Standalone Python script to validate recipes and items without needing Godot runtime.
Parses .tres files directly and generates validation report.
"""

import re
import os
from pathlib import Path
from collections import defaultdict
from datetime import datetime


class TresParser:
    """Simple parser for Godot .tres files"""
    
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
    def parse_recipe(file_path):
        """Parse a recipe .tres file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            recipe = {}
            
            # Parse fields
            patterns = {
                'slug': r'slug\s*=\s*(.+)',
                'recipe_name': r'recipe_name\s*=\s*(.+)',
                'description': r'description\s*=\s*"([^"]*)"',
                'required_class': r'required_class\s*=\s*"([^"]*)"',
                'required_level': r'required_level\s*=\s*(\d+)',
                'gold_cost': r'gold_cost\s*=\s*(\d+)',
                'energy_cost': r'energy_cost\s*=\s*([0-9.]+)',
                'input_1_slug': r'input_1_slug\s*=\s*(.+)',
                'input_1_quantity': r'input_1_quantity\s*=\s*(\d+)',
                'input_2_slug': r'input_2_slug\s*=\s*(.+)',
                'input_2_quantity': r'input_2_quantity\s*=\s*(\d+)',
                'input_3_slug': r'input_3_slug\s*=\s*(.+)',
                'input_3_quantity': r'input_3_quantity\s*=\s*(\d+)',
                'output_1_slug': r'output_1_slug\s*=\s*(.+)',
                'output_1_quantity': r'output_1_quantity\s*=\s*(\d+)',
                'output_2_slug': r'output_2_slug\s*=\s*(.+)',
                'output_2_quantity': r'output_2_quantity\s*=\s*(\d+)',
            }
            
            for key, pattern in patterns.items():
                match = re.search(pattern, content)
                if match:
                    recipe[key] = TresParser.parse_value(match.group(1))
                else:
                    # Set defaults
                    if 'slug' in key or 'class' in key or 'description' in key or 'name' in key:
                        recipe[key] = ""
                    else:
                        recipe[key] = 0 if 'quantity' in key or 'cost' in key or 'level' in key else ""
            
            return recipe
        except Exception as e:
            print(f"Error parsing {file_path}: {e}")
            return None
    
    @staticmethod
    def parse_item(file_path):
        """Parse an item .tres file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            item = {}
            
            # Parse item name
            match = re.search(r'item_name\s*=\s*(.+)', content)
            if match:
                item['item_name'] = TresParser.parse_value(match.group(1))
            else:
                item['item_name'] = ""
            
            # Parse tags
            match = re.search(r'tags\s*=\s*\[([^\]]*)\]', content)
            if match:
                tags_str = match.group(1)
                item['tags'] = [t.strip().strip('"') for t in tags_str.split(',') if t.strip()]
            else:
                item['tags'] = []
            
            return item
        except Exception as e:
            print(f"Error parsing {file_path}: {e}")
            return None


def validate_recipes_and_items(project_root):
    """Main validation function"""
    
    print("="*60)
    print("RECIPE & ITEM VALIDATION")
    print("="*60)
    print()
    
    project_path = Path(project_root)
    
    # Load all item slugs
    print("Loading items...")
    valid_item_slugs = set()
    items_by_slug = {}
    items_dir = project_path / "source" / "common" / "gameplay" / "items" / "materials"
    
    for item_file in items_dir.glob("*.tres"):
        slug = item_file.stem
        item = TresParser.parse_item(item_file)
        if item:
            valid_item_slugs.add(slug)
            items_by_slug[slug] = {
                'path': str(item_file.relative_to(project_path)),
                'name': item['item_name'],
                'tags': item['tags']
            }
    
    # Also check other item directories
    for item_subdir in ['combat', 'consumables', 'construction', 'food', 'furniture', 
                        'guild', 'household', 'luxury', 'storage', 'tools']:
        subdir = project_path / "source" / "common" / "gameplay" / "items" / item_subdir
        if subdir.exists():
            for item_file in subdir.glob("*.tres"):
                slug = item_file.stem
                item = TresParser.parse_item(item_file)
                if item:
                    valid_item_slugs.add(slug)
                    items_by_slug[slug] = {
                        'path': str(item_file.relative_to(project_path)),
                        'name': item['item_name'],
                        'tags': item['tags']
                    }
    
    print(f"Loaded {len(valid_item_slugs)} items")
    
    # Load all recipes
    print("Loading recipes...")
    recipes = []
    recipes_dir = project_path / "source" / "common" / "gameplay" / "crafting" / "recipes"
    
    for recipe_dir in recipes_dir.rglob("*.tres"):
        recipe = TresParser.parse_recipe(recipe_dir)
        if recipe:
            recipe['path'] = str(recipe_dir.relative_to(project_path))
            recipes.append(recipe)
    
    print(f"Loaded {len(recipes)} recipes")
    print()
    
    # Run validations
    print("Running validation checks...")
    
    recipes_with_no_inputs = []
    broken_recipe_references = []
    duplicate_recipes = defaultdict(list)
    items_produced_by_recipes = defaultdict(list)
    items_used_as_inputs = set()
    
    # Check each recipe
    for idx, recipe in enumerate(recipes):
        recipe_id = idx + 1
        
        # Check for no inputs
        has_input = False
        inputs = []
        
        if recipe.get('input_1_slug'):
            has_input = True
            inputs.append(recipe['input_1_slug'])
            items_used_as_inputs.add(recipe['input_1_slug'])
        
        if recipe.get('input_2_slug') and recipe.get('input_2_quantity', 0) > 0:
            has_input = True
            inputs.append(recipe['input_2_slug'])
            items_used_as_inputs.add(recipe['input_2_slug'])
        
        if recipe.get('input_3_slug') and recipe.get('input_3_quantity', 0) > 0:
            has_input = True
            inputs.append(recipe['input_3_slug'])
            items_used_as_inputs.add(recipe['input_3_slug'])
        
        if not has_input:
            recipes_with_no_inputs.append({
                'recipe_name': recipe.get('recipe_name', 'Unknown'),
                'slug': recipe.get('slug', 'unknown'),
                'path': recipe['path'],
                'gold_cost': recipe.get('gold_cost', 0),
                'energy_cost': recipe.get('energy_cost', 0.0)
            })
        
        # Check for broken references
        broken_refs = []
        
        for input_slug in inputs:
            if input_slug and input_slug not in valid_item_slugs:
                broken_refs.append(f"input: {input_slug}")
        
        # Check outputs
        if recipe.get('output_1_slug'):
            output_slug = recipe['output_1_slug']
            items_produced_by_recipes[output_slug].append(recipe_id)
            if output_slug not in valid_item_slugs:
                broken_refs.append(f"output: {output_slug}")
        
        if recipe.get('output_2_slug') and recipe.get('output_2_quantity', 0) > 0:
            output_slug = recipe['output_2_slug']
            items_produced_by_recipes[output_slug].append(recipe_id)
            if output_slug not in valid_item_slugs:
                broken_refs.append(f"output: {output_slug}")
        
        if broken_refs:
            broken_recipe_references.append({
                'recipe_name': recipe.get('recipe_name', 'Unknown'),
                'slug': recipe.get('slug', 'unknown'),
                'path': recipe['path'],
                'broken_refs': broken_refs
            })
        
        # Track duplicates
        if recipe.get('output_1_slug'):
            duplicate_recipes[recipe['output_1_slug']].append({
                'recipe_name': recipe.get('recipe_name', 'Unknown'),
                'recipe_id': recipe_id,
                'path': recipe['path'],
                'class': recipe.get('required_class', 'unknown'),
                'level': recipe.get('required_level', 1)
            })
    
    # Find duplicates (more than one recipe producing same item)
    actual_duplicates = {k: v for k, v in duplicate_recipes.items() if len(v) > 1}
    
    # Find unused crafted items
    unused_crafted_items = []
    for item_slug, recipe_ids in items_produced_by_recipes.items():
        if item_slug not in items_used_as_inputs:
            producing_recipes = duplicate_recipes.get(item_slug, [])
            unused_crafted_items.append({
                'item_slug': item_slug,
                'recipe_count': len(recipe_ids),
                'recipes': producing_recipes
            })
    
    # Find items without recipes (excluding raw materials)
    RAW_MATERIAL_TAGS = ['ore', 'wood', 'hide', 'meat', 'herb', 'plant', 'gathered', 'raw']
    
    items_without_recipes = []
    for slug, item_data in items_by_slug.items():
        if slug in items_produced_by_recipes:
            continue
        
        # Check if it's a raw material
        is_raw = any(tag in RAW_MATERIAL_TAGS for tag in item_data['tags'])
        if is_raw:
            continue
        
        # Check path patterns
        if '_ore' in slug or '_wood' in slug or '_hide' in slug or '_meat' in slug:
            continue
        
        items_without_recipes.append({
            'item_slug': slug,
            'item_name': item_data['name'],
            'path': item_data['path'],
            'tags': item_data['tags']
        })
    
    # Generate report
    print("Generating report...")
    
    total_issues = (
        len(recipes_with_no_inputs) +
        len(broken_recipe_references) +
        len(actual_duplicates) +
        len(unused_crafted_items) +
        len(items_without_recipes)
    )
    
    report = []
    report.append("# Recipe & Item Validation Report\n")
    report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
    
    # Summary
    report.append("## Summary\n\n")
    report.append(f"- Total Recipes: {len(recipes)}\n")
    report.append(f"- Total Items: {len(valid_item_slugs)}\n")
    report.append(f"- **Total Issues Found: {total_issues}**\n\n")
    
    # Issue breakdown
    report.append("### Issue Breakdown\n\n")
    report.append("| Issue Type | Count | Severity |\n")
    report.append("|------------|-------|----------|\n")
    report.append(f"| Recipes with No Inputs | {len(recipes_with_no_inputs)} | Warning |\n")
    report.append(f"| Items Without Recipes | {len(items_without_recipes)} | Info |\n")
    report.append(f"| Broken Recipe References | {len(broken_recipe_references)} | Critical |\n")
    report.append(f"| Duplicate Recipes | {len(actual_duplicates)} | Warning |\n")
    report.append(f"| Unused Crafted Items | {len(unused_crafted_items)} | Info |\n")
    report.append("\n")
    
    # Detailed sections
    if broken_recipe_references:
        report.append("\n## 🔴 CRITICAL: Broken Recipe References\n\n")
        report.append("Recipes referencing non-existent items. These will cause runtime errors!\n\n")
        for issue in broken_recipe_references:
            report.append(f"### {issue['recipe_name']}\n\n")
            report.append(f"- **Path:** `{issue['path']}`\n")
            report.append(f"- **Slug:** `{issue['slug']}`\n")
            report.append("- **Broken References:**\n")
            for ref in issue['broken_refs']:
                report.append(f"  - {ref}\n")
            report.append("\n")
    
    if recipes_with_no_inputs:
        report.append("\n## ⚠️ WARNING: Recipes with No Inputs\n\n")
        report.append("Recipes that require only gold/energy but no material inputs.\n\n")
        for issue in recipes_with_no_inputs:
            report.append(f"### {issue['recipe_name']}\n\n")
            report.append(f"- **Path:** `{issue['path']}`\n")
            report.append(f"- **Slug:** `{issue['slug']}`\n")
            report.append(f"- **Cost:** {issue['gold_cost']} gold, {issue['energy_cost']} energy\n")
            report.append("\n")
    
    if actual_duplicates:
        report.append("\n## ⚠️ WARNING: Duplicate Recipes\n\n")
        report.append("Multiple recipes producing the same item. May cause confusion or balance issues.\n\n")
        for item_slug, recipe_list in actual_duplicates.items():
            report.append(f"### Item: {item_slug} ({len(recipe_list)} recipes)\n\n")
            for recipe in recipe_list:
                report.append(f"- **{recipe['recipe_name']}** (ID: {recipe['recipe_id']})\n")
                report.append(f"  - Path: `{recipe['path']}`\n")
                report.append(f"  - Class: {recipe['class']}, Level: {recipe['level']}\n")
            report.append("\n")
    
    if items_without_recipes:
        report.append("\n## ℹ️ INFO: Items Without Recipes\n\n")
        report.append("Craftable items that have no recipe. Excluding raw materials.\n\n")
        for issue in items_without_recipes:
            report.append(f"### {issue['item_name']}\n\n")
            report.append(f"- **Slug:** `{issue['item_slug']}`\n")
            report.append(f"- **Path:** `{issue['path']}`\n")
            report.append(f"- **Tags:** {issue['tags']}\n")
            report.append("\n")
    
    if unused_crafted_items:
        report.append("\n## ℹ️ INFO: Unused Crafted Items\n\n")
        report.append("Items that are crafted but never used as inputs in other recipes. Potential dead ends.\n\n")
        for issue in unused_crafted_items:
            report.append(f"### Item: {issue['item_slug']}\n\n")
            report.append(f"- **Produced by {issue['recipe_count']} recipe(s):**\n")
            for recipe in issue['recipes']:
                report.append(f"  - {recipe['recipe_name']} (ID: {recipe['recipe_id']}) - `{recipe['path']}`\n")
            report.append("\n")
    
    # Save report
    report_text = ''.join(report)
    report_path = project_path / "VALIDATION_REPORT.md"
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(report_text)
    
    print(f"\nReport saved to: {report_path}")
    print("\n" + "="*60)
    print("QUICK SUMMARY:")
    print(f"- Total Recipes: {len(recipes)}")
    print(f"- Total Items: {len(valid_item_slugs)}")
    print(f"- Total Issues: {total_issues}")
    print("")
    print(f"  - Recipes with No Inputs: {len(recipes_with_no_inputs)}")
    print(f"  - Items Without Recipes: {len(items_without_recipes)}")
    print(f"  - Broken Recipe References: {len(broken_recipe_references)}")
    print(f"  - Duplicate Recipes: {len(actual_duplicates)}")
    print(f"  - Unused Crafted Items: {len(unused_crafted_items)}")
    print("="*60)


if __name__ == "__main__":
    # Detect project root
    script_dir = Path(__file__).parent
    validate_recipes_and_items(script_dir)

