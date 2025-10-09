#!/usr/bin/env python3
"""
Removes duplicate recipes from the tier1 folder.
Keeps class-specific recipes (forager, miner, trapper, etc.)
"""

import re
import shutil
from pathlib import Path


def remove_tier1_recipes(project_root):
    """Remove all recipe files from tier1 folder"""
    tier1_dir = project_root / "source" / "common" / "gameplay" / "crafting" / "recipes" / "tier1"
    
    if not tier1_dir.exists():
        print(f"ERROR: tier1 directory not found at {tier1_dir}")
        return []
    
    # Create backup
    backup_dir = project_root / "migration_backups" / "tier1_recipes"
    backup_dir.mkdir(parents=True, exist_ok=True)
    
    removed_files = []
    recipe_files = list(tier1_dir.glob("*.tres"))
    
    print(f"Found {len(recipe_files)} recipes in tier1 folder")
    print()
    
    for recipe_file in recipe_files:
        # Backup
        shutil.copy2(recipe_file, backup_dir / recipe_file.name)
        
        # Delete
        recipe_file.unlink()
        removed_files.append(recipe_file.name)
        print(f"  OK Removed: {recipe_file.name}")
    
    return removed_files


def remove_tier1_from_index(index_path, project_root):
    """Remove tier1 recipe entries from recipes_index.tres"""
    with open(index_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Backup
    backup_path = project_root / "migration_backups" / "recipes_index_before_tier1_removal.tres"
    backup_path.parent.mkdir(parents=True, exist_ok=True)
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    # Find and remove all tier1 entries
    # Pattern matches dictionary entries for tier1 recipes
    pattern = r',?\s*\{\s*&"hash":[^}]*?"path":\s*"[^"]*?/tier1/[^"]*?"[^}]*?\}'
    
    matches = re.findall(pattern, content, re.DOTALL)
    print(f"\nFound {len(matches)} tier1 entries in recipes_index.tres")
    
    # Remove matches
    new_content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    # Clean up any double commas or trailing commas before ]
    new_content = re.sub(r',\s*,', ',', new_content)
    new_content = re.sub(r',(\s*\]\))', r'\1', new_content)
    
    with open(index_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"OK Removed {len(matches)} tier1 recipe entries from index")
    
    return len(matches)


def main():
    print("="*70)
    print("REMOVE DUPLICATE RECIPES (TIER1 FOLDER)")
    print("="*70)
    print()
    
    project_root = Path(__file__).parent
    recipes_index = project_root / "source" / "common" / "registry" / "indexes" / "recipes_index.tres"
    
    print("Step 1: Removing recipe files from tier1 folder...")
    print()
    removed_files = remove_tier1_recipes(project_root)
    
    if not removed_files:
        print("No files to remove!")
        return
    
    print()
    print(f"Removed {len(removed_files)} recipe files")
    print()
    
    print("Step 2: Updating recipes_index.tres...")
    removed_entries = remove_tier1_from_index(recipes_index, project_root)
    
    # Try to remove the tier1 directory if empty
    tier1_dir = project_root / "source" / "common" / "gameplay" / "crafting" / "recipes" / "tier1"
    try:
        if tier1_dir.exists() and not any(tier1_dir.iterdir()):
            tier1_dir.rmdir()
            print(f"\nOK Removed empty tier1 directory")
    except Exception as e:
        print(f"\nNote: Could not remove tier1 directory: {e}")
    
    print()
    print("="*70)
    print("DUPLICATE REMOVAL COMPLETE!")
    print("="*70)
    print()
    print(f"Removed {len(removed_files)} duplicate recipe files")
    print(f"Removed {removed_entries} entries from recipes_index.tres")
    print()
    print(f"Backups saved to: {project_root / 'migration_backups'}")
    print()
    print("Next step: Run validation to confirm duplicates are resolved!")


if __name__ == "__main__":
    main()

