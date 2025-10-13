#!/usr/bin/env python3
"""Restore recipes from backup"""
import shutil
from pathlib import Path

# Paths
backup_dir = Path("economy_rebalance_backup/20251012_113608/recipes")
target_dir = Path("source/common/gameplay/crafting/recipes")

print("Restoring recipes from backup...")
print(f"Backup: {backup_dir}")
print(f"Target: {target_dir}")

if not backup_dir.exists():
    print(f"ERROR: Backup directory not found: {backup_dir}")
    exit(1)

# Count files
backup_files = list(backup_dir.glob("**/*.tres"))
print(f"\nFound {len(backup_files)} recipe files in backup")

# Restore each file
restored = 0
for backup_file in backup_files:
    relative_path = backup_file.relative_to(backup_dir)
    target_file = target_dir / relative_path
    
    # Create parent directory if needed
    target_file.parent.mkdir(parents=True, exist_ok=True)
    
    # Copy file
    shutil.copy2(backup_file, target_file)
    restored += 1
    
    if restored % 10 == 0:
        print(f"  Restored {restored}/{len(backup_files)} files...")

print(f"\n✓ Successfully restored {restored} recipe files!")
print("\nRecipes have been reverted to their original state.")

