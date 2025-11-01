# Registry Update Script

## Overview

The `update_registry.py` script automatically scans your filesystem for items and recipes, validates them, and updates the registries (`items_index.tres` and `recipes_index.tres`) to include any missing valid entries.

## Features

- **Automatic Scanning**: Scans all item and recipe `.tres` files in the filesystem
- **Validation**: Only includes items/recipes that meet all requirements:
  - **Items** must have:
    - Valid script_class (MaterialItem, WeaponItem, ConsumableItem, GearItem, etc.)
    - item_name
    - item_icon (can be null)
    - description
    - can_trade
    - can_sell
    - minimum_price
    - stack_limit
    - tags
  - **Recipes** must have:
    - script_class="CraftingRecipe"
    - slug
    - recipe_name
    - recipe_icon (can be null)
    - description
    - **required_class** (miner/forager/trapper/blacksmith/culinarian/artisan)
    - **required_level** (must be >= 1)
    - gold_cost
    - energy_cost
    - output_1_slug (at least one output is required)
- **Automatic Updates**: Updates registry files with proper IDs, hashes, and timestamps
- **Error Reporting**: Reports invalid items/recipes that were skipped

## Usage

Run the script from the project root:

```bash
python update_registry.py
```

## What It Does

1. **Loads Registries**: Reads current `items_index.tres` and `recipes_index.tres`
2. **Scans Filesystem**: Finds all `.tres` files in:
   - `source/common/gameplay/items/` (all subdirectories)
   - `source/common/gameplay/crafting/recipes/` (all subdirectories)
3. **Validates**: Checks each file to ensure it's a complete, valid item or recipe
4. **Finds Missing**: Compares filesystem files to registry entries
5. **Updates**: Adds missing valid items/recipes to their respective registries
6. **Reports**: Shows summary of what was added and what was skipped

## Output Example

```
======================================================================
REGISTRY UPDATE SCRIPT
======================================================================

Loading registries...
  Items in registry: 317
  Recipes in registry: 204

Scanning filesystem for items...
  Found 290 item files
Scanning filesystem for recipes...
  Found 187 recipe files

Validating items...
  Missing valid items: 5
  Invalid items (not added): 2
  Invalid items:
    - broken_item: Missing item_name, Missing description
    - incomplete_item: Missing can_trade

Validating recipes...
  Missing valid recipes: 3
  Invalid recipes (not added): 1
  Invalid recipes:
    - broken_recipe: Missing required_class, Missing required_level

Updating items_index.tres with 5 new items...
  ✓ Items registry updated successfully

Updating recipes_index.tres with 3 new recipes...
  ✓ Recipes registry updated successfully

======================================================================
SUMMARY
======================================================================
Items added to registry: 5
Recipes added to registry: 3
Invalid items skipped: 2
Invalid recipes skipped: 1
======================================================================
```

## Important Notes

- **Validation is Strict**: Items/recipes without required fields (especially `required_class` and `required_level` for recipes) will NOT be added
- **Non-Destructive**: Only adds missing entries; doesn't modify existing ones
- **Automatic IDs**: New entries get sequential IDs starting from `next_id`
- **Hash Generation**: Recipe entries get SHA256 hashes for their slugs
- **Version Updates**: Registry version timestamps are updated automatically

## Troubleshooting

If items/recipes are not being added:

1. **Check Validation Errors**: The script reports why items/recipes are invalid
2. **Required Fields**: Ensure recipes have `required_class` and `required_level >= 1`
3. **File Format**: Ensure `.tres` files are properly formatted with all required fields
4. **Path Issues**: Ensure files are in the correct directories (items/ or recipes/ subdirectories)

## Safety

- Creates backups implicitly (via version control if you're using git)
- Only modifies registry files, never item/recipe files themselves
- Can be run multiple times safely (won't duplicate entries)


