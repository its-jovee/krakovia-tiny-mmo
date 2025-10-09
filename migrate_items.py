#!/usr/bin/env python3
"""
Complete item migration script:
1. Identifies items with _new suffix
2. Removes old versions
3. Renames _new files to clean names
4. Updates items_index.tres
5. Updates all recipes to use clean names
"""

import re
import os
import shutil
from pathlib import Path
from collections import defaultdict


def find_items_to_migrate(items_dir):
    """Find all items with _new suffix and check for old versions"""
    migrations = []
    
    for new_file in items_dir.glob("*_new.tres"):
        new_stem = new_file.stem  # e.g., "grapes_new"
        clean_name = new_stem.replace("_new", "")  # e.g., "grapes"
        old_file = items_dir / f"{clean_name}.tres"
        
        migrations.append({
            'new_file': new_file,
            'old_file': old_file if old_file.exists() else None,
            'clean_name': clean_name,
            'new_stem': new_stem
        })
    
    return migrations


def backup_file(file_path, backup_dir):
    """Create a backup of a file"""
    backup_dir.mkdir(exist_ok=True)
    backup_path = backup_dir / file_path.name
    shutil.copy2(file_path, backup_path)
    print(f"  Backed up: {file_path.name}")


def update_recipe_file(recipe_path, slug_mapping):
    """Update recipe to use clean slug names"""
    try:
        with open(recipe_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        changes = []
        
        # Update input slugs
        for old_slug, new_slug in slug_mapping.items():
            # Match patterns like: input_1_slug = &"grapes_new"
            pattern = rf'(input_\d_slug\s*=\s*&")({old_slug})(")'
            matches = re.findall(pattern, content)
            if matches:
                content = re.sub(pattern, rf'\1{new_slug}\3', content)
                changes.append(f"{old_slug} -> {new_slug} (input)")
            
            # Match patterns like: output_1_slug = &"grapes_new"
            pattern = rf'(output_\d_slug\s*=\s*&")({old_slug})(")'
            matches = re.findall(pattern, content)
            if matches:
                content = re.sub(pattern, rf'\1{new_slug}\3', content)
                changes.append(f"{old_slug} -> {new_slug} (output)")
        
        if content != original_content:
            with open(recipe_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return changes
        
        return None
    except Exception as e:
        print(f"  ERROR updating {recipe_path}: {e}")
        return None


def update_items_index(index_path, slug_mapping):
    """Update items_index.tres to use clean slug names"""
    try:
        with open(index_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        changes = []
        
        for old_slug, new_slug in slug_mapping.items():
            # Update slug entries
            pattern = rf'(&"slug":\s*&")({old_slug})(")'
            if re.search(pattern, content):
                content = re.sub(pattern, rf'\1{new_slug}\3', content)
                changes.append(f"{old_slug} -> {new_slug}")
            
            # Update path entries (remove _new from filename)
            pattern = rf'(res://source/common/gameplay/items/materials/)({old_slug})(\.tres")'
            if re.search(pattern, content):
                content = re.sub(pattern, rf'\1{new_slug}\3', content)
        
        if content != original_content:
            with open(index_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"\nOK Updated items_index.tres: {len(changes)} slug changes")
            return True
        
        return False
    except Exception as e:
        print(f"\nERROR updating items_index: {e}")
        return False


def main():
    print("="*70)
    print("ITEM MIGRATION SCRIPT")
    print("="*70)
    print()
    
    project_root = Path(__file__).parent
    items_dir = project_root / "source" / "common" / "gameplay" / "items" / "materials"
    recipes_dir = project_root / "source" / "common" / "gameplay" / "crafting" / "recipes"
    backup_dir = project_root / "migration_backups"
    index_path = project_root / "source" / "common" / "registry" / "indexes" / "items_index.tres"
    
    # Step 1: Find migrations
    print("Step 1: Analyzing items...")
    migrations = find_items_to_migrate(items_dir)
    print(f"Found {len(migrations)} items with _new suffix")
    print()
    
    # Step 2: Show migration plan
    print("Step 2: Migration Plan")
    print("-" * 70)
    
    slug_mapping = {}  # old_slug → new_slug
    files_to_delete = []
    files_to_rename = []
    
    for mig in migrations:
        clean_name = mig['clean_name']
        new_stem = mig['new_stem']
        
        print(f"\n  {new_stem} -> {clean_name}")
        
        if mig['old_file']:
            print(f"    - DELETE old: {mig['old_file'].name}")
            files_to_delete.append(mig['old_file'])
        
        print(f"    - RENAME: {mig['new_file'].name} -> {clean_name}.tres")
        files_to_rename.append((mig['new_file'], items_dir / f"{clean_name}.tres"))
        
        # Track slug changes
        slug_mapping[new_stem] = clean_name
    
    print()
    print("="*70)
    print(f"Summary: {len(files_to_delete)} files to delete, {len(files_to_rename)} files to rename")
    print("="*70)
    print()
    
    # Step 3: Create backups
    print("Step 3: Creating backups...")
    backup_dir.mkdir(exist_ok=True)
    
    for file_path in files_to_delete:
        backup_file(file_path, backup_dir / "deleted")
    
    for old_path, new_path in files_to_rename:
        backup_file(old_path, backup_dir / "renamed")
    
    backup_file(index_path, backup_dir)
    
    print()
    
    # Step 4: Delete old files
    print("Step 4: Deleting old item files...")
    for file_path in files_to_delete:
        try:
            file_path.unlink()
            print(f"  OK Deleted: {file_path.name}")
        except Exception as e:
            print(f"  ERROR Failed to delete {file_path.name}: {e}")
    
    print()
    
    # Step 5: Rename _new files
    print("Step 5: Renaming _new files to clean names...")
    for old_path, new_path in files_to_rename:
        try:
            old_path.rename(new_path)
            print(f"  OK Renamed: {old_path.name} -> {new_path.name}")
        except Exception as e:
            print(f"  ERROR Failed to rename {old_path.name}: {e}")
    
    print()
    
    # Step 6: Update items_index.tres
    print("Step 6: Updating items_index.tres...")
    update_items_index(index_path, slug_mapping)
    
    print()
    
    # Step 7: Update all recipes
    print("Step 7: Updating recipes to use clean slug names...")
    recipe_files = list(recipes_dir.rglob("*.tres"))
    updated_count = 0
    
    for recipe_path in recipe_files:
        changes = update_recipe_file(recipe_path, slug_mapping)
        if changes:
            updated_count += 1
            print(f"  OK {recipe_path.relative_to(project_root)}")
            for change in changes:
                print(f"      - {change}")
    
    print()
    print(f"Updated {updated_count} recipe files")
    
    print()
    print("="*70)
    print("MIGRATION COMPLETE!")
    print("="*70)
    print()
    print(f"Backups saved to: {backup_dir}")
    print()
    print("Next steps:")
    print("  1. Run the validation script again to verify fixes")
    print("  2. Test the game to ensure recipes load correctly")
    print("  3. If everything works, you can delete the migration_backups folder")
    print()


if __name__ == "__main__":
    main()

