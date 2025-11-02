extends Node

## Test script to verify pumpkin_head item loads correctly
## Run this in Godot by attaching to a test scene and running it

func _ready() -> void:
	print("=" * 60)
	print("PUMPKIN HEAD ITEM TEST")
	print("=" * 60)
	
	# Test 1: Load by slug
	print("\n[Test 1] Loading by slug 'pumpkin_head'...")
	var item_by_slug = ContentRegistryHub.load_by_slug(&"items", &"pumpkin_head")
	if item_by_slug:
		print("  ✅ Loaded: %s" % item_by_slug.item_name)
		print("  → Class: %s" % item_by_slug.get_class())
		print("  → Is EquipmentItem: %s" % (item_by_slug is EquipmentItem))
		print("  → Script path: %s" % item_by_slug.get_script().resource_path)
		
		if item_by_slug is EquipmentItem:
			var equip_item := item_by_slug as EquipmentItem
			print("  → Equipment resource: %s" % ("YES" if equip_item.equipment else "NULL"))
			print("  → Slot: %s" % (equip_item.slot.key if equip_item.slot else "NULL"))
			print("  → Required level: %d" % equip_item.required_level)
			print("  → Required classes: %s" % equip_item.required_classes)
	else:
		print("  ✗ Failed to load by slug!")
	
	# Test 2: Load by ID
	print("\n[Test 2] Loading by ID 319...")
	var item_by_id = ContentRegistryHub.load_by_id(&"items", 319)
	if item_by_id:
		print("  ✅ Loaded: %s" % item_by_id.item_name)
		print("  → Is EquipmentItem: %s" % (item_by_id is EquipmentItem))
	else:
		print("  ✗ Failed to load by ID!")
	
	# Test 3: Get ID from slug
	print("\n[Test 3] Getting ID from slug...")
	var item_id = ContentRegistryHub.id_from_slug(&"items", &"pumpkin_head")
	print("  → ID: %d" % item_id)
	
	# Test 4: Check if EquipmentItem class exists
	print("\n[Test 4] Checking EquipmentItem class...")
	var test_script = load("res://source/common/gameplay/items/equipment_item.gd")
	if test_script:
		print("  ✅ EquipmentItem script loads")
		print("  → Path: %s" % test_script.resource_path)
	else:
		print("  ✗ EquipmentItem script not found!")
	
	# Test 5: Load the .tres file directly
	print("\n[Test 5] Loading .tres file directly...")
	var direct_load = load("res://source/common/gameplay/items/equipment/pumpkin_head_item.tres")
	if direct_load:
		print("  ✅ Direct load successful")
		print("  → Item name: %s" % direct_load.item_name)
		print("  → Class: %s" % direct_load.get_class())
		print("  → Is EquipmentItem: %s" % (direct_load is EquipmentItem))
	else:
		print("  ✗ Direct load failed!")
	
	print("\n" + "=" * 60)
	print("Test complete! Check results above.")
	print("=" * 60)

