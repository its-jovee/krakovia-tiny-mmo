#!/usr/bin/env python3
"""
Update recipes_index.tres with new recipes and moved interdependent recipes
"""

# Existing recipes to keep (IDs 1-83)
existing_recipes = [
    ("copper_ingot_recipe", "miner"),
    ("pottery_set_recipe", "miner"),
    ("stone_block_recipe", "miner"),
    ("glass_bottle_recipe", "miner"),
    ("brick_recipe", "miner"),
    ("oak_planks_recipe", "forager"),
    ("charcoal_recipe", "forager"),
    ("flour_recipe", "forager"),
    ("thread_recipe", "forager"),
    ("basic_fabric_recipe", "forager"),
    ("basic_leather_recipe", "trapper"),
    ("quality_leather_recipe", "trapper"),
    ("cured_leather_recipe", "trapper"),
    ("heavy_leather_recipe", "trapper"),
    ("masterwork_leather_recipe", "trapper"),
]

# Moved interdependent recipes (update paths)
moved_recipes = [
    ("steel_sword_recipe", "miner"),
    ("steel_chestplate_recipe", "miner"),
    ("wall_section_recipe", "miner"),
    ("workshop_tools_recipe", "miner"),
    ("wooden_bow_recipe", "forager"),
    ("simple_bag_recipe", "forager"),
    ("storage_chest_recipe", "forager"),
    ("throne_recipe", "forager"),
    ("wine_recipe", "forager"),
    ("wooden_beam_recipe", "forager"),
    ("seasoned_meat_recipe", "forager"),
    ("reinforced_gloves_recipe", "trapper"),
    ("royal_garments_recipe", "trapper"),
    ("simple_jewelry_recipe", "trapper"),
    ("soap_recipe", "trapper"),
    ("spiced_roast_recipe", "trapper"),
    ("trophy_mount_recipe", "trapper"),
    ("winter_coat_recipe", "trapper"),
]

# New recipes
new_miner = [
    "iron_helmet_recipe", "iron_boots_recipe", "iron_sword_new_recipe", "arrows_recipe",
    "minor_health_potion_recipe", "bellows_recipe", "linen_fabric_recipe", "canvas_recipe",
    "wool_fabric_recipe", "dyes_recipe", "colored_fabric_recipe", "silk_fabric_recipe",
    "gold_thread_recipe", "health_potion_new_recipe", "greater_health_potion_recipe",
    "night_vision_potion_recipe", "fire_resistance_potion_recipe", "agricultural_tools_recipe",
    "crafting_supplies_recipe", "reinforced_door_recipe", "bridge_section_recipe",
    "fortification_section_recipe", "monument_base_recipe", "forge_station_recipe",
    "memorial_plaque_recipe", "alchemy_table_recipe", "premium_workshop_tools_recipe",
    "crown_recipe", "legendary_weapon_recipe", "masterwork_armor_set_recipe", "guild_hall_section_recipe"
]

new_forager = [
    "olive_oil_recipe", "ale_recipe", "cider_recipe", "beer_recipe", "alcohol_base_recipe",
    "barrel_recipe", "candle_set_recipe", "pillow_recipe", "blanket_recipe", "linen_shirt_recipe",
    "fertilizer_recipe", "hearty_stew_recipe", "honey_glazed_ham_recipe", "preserved_rations_recipe",
    "luxury_pastries_recipe", "fine_chair_recipe", "display_cabinet_recipe", "ornate_table_recipe",
    "decorative_statue_recipe", "embroidered_tapestry_recipe", "tanning_rack_recipe",
    "lantern_recipe", "perfume_recipe", "luxury_soap_recipe", "luxury_polish_recipe",
    "fine_cloak_recipe", "mead_recipe", "herb_tea_recipe", "fruit_preserves_recipe",
    "vegetable_stew_recipe", "seed_pouch_recipe", "decorative_vase_recipe",
    "farming_plot_kit_recipe", "feast_table_recipe"
]

new_trapper = [
    "rope_recipe", "bandages_recipe", "gathering_satchel_recipe", "large_backpack_recipe",
    "leather_jacket_recipe", "leather_chest_recipe", "medical_kit_recipe", "antidote_recipe",
    "medicinal_tincture_recipe", "basic_tool_set_recipe", "construction_kit_recipe",
    "explorer_pack_recipe", "master_satchel_recipe", "masters_satchel_recipe",
    "hearty_stew_trapper_recipe", "honey_glazed_ham_trapper_recipe", "preserved_rations_trapper_recipe",
    "raw_meat_processing_recipe", "leather_pants_recipe", "leather_boots_recipe",
    "leather_gloves_recipe", "leather_helmet_recipe", "heavy_leather_armor_recipe",
    "fur_cloak_recipe", "hunting_bow_recipe", "trap_kit_recipe", "skinning_knife_recipe",
    "tanning_solution_recipe", "leather_belt_recipe", "quiver_recipe", "hunting_trophy_recipe",
    "survival_kit_recipe", "camouflage_cloak_recipe", "master_hunters_set_recipe", "legendary_bow_recipe"
]

def generate_hash(slug):
    """Generate a fake but consistent hash for recipe entry"""
    import hashlib
    return hashlib.sha256(slug.encode()).hexdigest()

# Read existing entries from file
import re

with open("source/common/registry/indexes/recipes_index.tres", "r", encoding="utf-8") as f:
    content = f.read()
    
# Extract existing entries (IDs 1-83, skipping deleted 84-89)
pattern = r'&"id": (\d+),\s*&"path": "([^"]+)",\s*&"slug": &"([^"]+)"'
matches = re.findall(pattern, content)

entries = []
for match in matches:
    entry_id = int(match[0])
    if entry_id <= 83:  # Keep only first 83
        entries.append(match)

# Add moved recipes (starting from ID 84)
next_id = 84
for slug, class_name in moved_recipes:
    path = f"res://source/common/gameplay/crafting/recipes/{class_name}/{slug}.tres"
    entries.append((str(next_id), path, slug))
    next_id += 1

# Add new recipes
for slug in new_miner:
    path = f"res://source/common/gameplay/crafting/recipes/miner/{slug}.tres"
    entries.append((str(next_id), path, slug))
    next_id += 1

for slug in new_forager:
    path = f"res://source/common/gameplay/crafting/recipes/forager/{slug}.tres"
    entries.append((str(next_id), path, slug))
    next_id += 1

for slug in new_trapper:
    path = f"res://source/common/gameplay/crafting/recipes/trapper/{slug}.tres"
    entries.append((str(next_id), path, slug))
    next_id += 1

# Generate output
output = f"""[gd_resource type="Resource" script_class="ContentIndex" load_steps=2 format=3 uid="uid://b7c8eae0f1g2"]

[ext_resource type="Script" uid="uid://0wmtcxri41vp" path="res://source/common/registry/content_index.gd" id="1_gemjq"]

[resource]
script = ExtResource("1_gemjq")
content_name = &"recipes"
version = 1760000003
next_id = {next_id}
entries = Array[Dictionary](["""

for i, (entry_id, path, slug) in enumerate(entries):
    hash_val = generate_hash(slug)
    if i > 0:
        output += ", "
    output += f"""{{
&"hash": "{hash_val}",
&"id": {entry_id},
&"path": "{path}",
&"slug": &"{slug}"
}}"""

output += """])
metadata/slug = &"recipes_index"
metadata/id = 4
"""

with open("source/common/registry/indexes/recipes_index.tres", "w", encoding="utf-8", newline='\n') as f:
    f.write(output)

print(f"✓ Updated recipes_index.tres with {len(entries)} total recipes")
print(f"  - Kept: 83 existing recipes")
print(f"  - Moved: 18 interdependent recipes")
print(f"  - Added: {len(new_miner)} miner + {len(new_forager)} forager + {len(new_trapper)} trapper = {len(new_miner) + len(new_forager) + len(new_trapper)} new recipes")
print(f"  - Next ID: {next_id}")

